#!/usr/bin/env bash
# Minikube dev control: start | status | stop
# - start: starts Minikube, dashboard (bg), tunnel (bg), and port-forwards all Services in a namespace
# - status: verifies cluster components, shows dashboard URL, tunnel/process state, services and forwards
# - stop: stops all forwards, dashboard, tunnel, and Minikube
#
# Env overrides:
#   MINIKUBE_PROFILE=minikube
#   NAMESPACE=sample-app
#   PF_PIDFILE=.minikube-pf-${NAMESPACE}.pids
#   DASH_PIDFILE=.minikube-dashboard.pid
#   TUNNEL_PIDFILE=.minikube-tunnel.pid
#
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-minikube}"
NAMESPACE="${NAMESPACE:-sample-app}"
PF_PIDFILE_DEFAULT=".minikube-pf-${NAMESPACE}.pids"
PF_PIDFILE="${PF_PIDFILE:-$PF_PIDFILE_DEFAULT}"
DASH_PIDFILE="${DASH_PIDFILE:-.minikube-dashboard.pid}"
TUNNEL_PIDFILE="${TUNNEL_PIDFILE:-.minikube-tunnel.pid}"
# Allow disabling tunnel to avoid sudo dependency in non-interactive environments
TUNNEL_ENABLED="${TUNNEL_ENABLED:-true}"

# Qdrant docker settings (background service)
QDRANT_IMAGE="${QDRANT_IMAGE:-qdrant/qdrant}"
QDRANT_CONTAINER="${QDRANT_CONTAINER:-qdrant-dev}"
QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_ENABLED="${QDRANT_ENABLED:-true}"
# Minikube wait controls (tunable)
WAIT_TARGETS="${MINIKUBE_WAIT_TARGETS:-all}"
WAIT_TIMEOUT="${MINIKUBE_WAIT_TIMEOUT:-8m}"

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
err() { printf '[%s] ERROR: %s\n' "$(date -Is)" "$*" >&2; }
die() { err "$*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

deps() {
  need minikube
  need kubectl
  # Docker is optional; if missing, disable Qdrant integration gracefully
  if [[ "${QDRANT_ENABLED}" == "true" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      err "docker not found; disabling Qdrant integration for this session"
      QDRANT_ENABLED="false"
    fi
  fi
}

# Resilient Minikube start helpers
is_cluster_running() {
  local out
  out="$(minikube status -p "${PROFILE}" 2>/dev/null || true)"
  grep -q "host: Running" <<<"${out}" && \
  grep -q "kubelet: Running" <<<"${out}" && \
  grep -q "apiserver: Running" <<<"${out}"
}

start_minikube_resilient() {
  if is_cluster_running; then
    log "Minikube already running (profile=${PROFILE})"
    return 0
  fi
  log "Starting Minikube (profile=${PROFILE})..."
  set +e
  minikube start -p "${PROFILE}" --wait="${WAIT_TARGETS}" --wait-timeout="${WAIT_TIMEOUT}"
  local rc=$?
  set -e
  if [[ ${rc} -ne 0 ]]; then
    err "minikube start exited with code ${rc}. Verifying cluster health..."
    if is_cluster_running; then
      log "Cluster appears healthy despite start error; continuing."
      return 0
    fi
    err "Cluster not healthy; retrying with relaxed waits..."
    set +e
    minikube start -p "${PROFILE}" --wait="apiserver,kubelet" --wait-timeout="5m"
    rc=$?
    set -e
    if [[ ${rc} -ne 0 ]] && ! is_cluster_running; then
      die "Minikube failed to start after retry. See: minikube logs -p ${PROFILE}"
    fi
  fi
  log "Minikube started."
}

dashboard_start_bg() {
  # Get URL (non-blocking) and open if possible, then run dashboard in bg for proxy
  local url=""
  if command -v timeout >/dev/null 2>&1; then
    url="$(timeout 3s minikube dashboard -p "${PROFILE}" --url 2>/dev/null || true)"
  fi
  if [[ -n "${url}" ]]; then
    log "Dashboard URL: ${url}"
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "${url}" >/dev/null 2>&1 || true; fi
  fi
  # Run proxy in background
  nohup minikube dashboard -p "${PROFILE}" >/dev/null 2>&1 &
  echo $! > "${DASH_PIDFILE}"
  log "Dashboard started (PID=$(cat "${DASH_PIDFILE}"))"
}

dashboard_status() {
  local have_pid="false"
  if [[ -f "${DASH_PIDFILE}" ]]; then
    local pid; pid="$(cat "${DASH_PIDFILE}")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      log "Dashboard process running (PID=${pid})"
      have_pid="true"
    else
      log "Dashboard process not running (PID file present but stale)"
    fi
  else
    log "Dashboard PID file not found (dashboard may be running from another session)"
  fi
  # Only attempt URL lookup if a dashboard process is known-running; guard with timeout to avoid hanging.
  if [[ "${have_pid}" == "true" ]] && command -v timeout >/dev/null 2>&1; then
    local url; url="$(timeout 2s minikube dashboard -p "${PROFILE}" --url 2>/dev/null || true)"
    [[ -n "${url}" ]] && log "Dashboard URL: ${url}"
  fi
  return 0
}

dashboard_stop() {
  if [[ -f "${DASH_PIDFILE}" ]]; then
    local pid; pid="$(cat "${DASH_PIDFILE}")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      log "Stopping dashboard (PID=${pid})"
      kill "${pid}" 2>/dev/null || true
    fi
    rm -f "${DASH_PIDFILE}"
  fi
}

tunnel_start_bg() {
  if [[ "${TUNNEL_ENABLED}" != "true" ]]; then
    log "Tunnel disabled via TUNNEL_ENABLED=false; skipping minikube tunnel."
    return 0
  fi
  log "Starting minikube tunnel in background..."
  # Require sudo but avoid hanging on password prompts in non-interactive sessions
  if ! command -v sudo >/dev/null 2>&1; then
    err "sudo not found; skipping tunnel. You can run manually: 'sudo minikube tunnel -p ${PROFILE}'"
    return 0
  fi
  # Validate sudo can run without password prompt (cached credentials)
  if ! sudo -n true 2>/dev/null; then
    err "sudo password required; skipping background tunnel. Run manually: 'sudo minikube tunnel -p ${PROFILE}'"
    return 0
  fi
  # Start in background and record PID; try to capture real tunnel PID
  sudo -E nohup minikube tunnel -p "${PROFILE}" >/dev/null 2>&1 &
  echo $! > "${TUNNEL_PIDFILE}"
  sleep 1
  local tpid; tpid="$(pgrep -f "minikube tunnel -p ${PROFILE}" | head -n1 || true)"
  if [[ -n "${tpid}" ]]; then
    echo "${tpid}" > "${TUNNEL_PIDFILE}"
  fi
  log "Tunnel started (PID=$(cat "${TUNNEL_PIDFILE}"))"
}

tunnel_status() {
  if [[ "${TUNNEL_ENABLED}" != "true" ]]; then
    log "Tunnel disabled via TUNNEL_ENABLED=false"
    return 0
  fi
  local pids=""
  if [[ -f "${TUNNEL_PIDFILE}" ]]; then
    pids="$(cat "${TUNNEL_PIDFILE}")"
  else
    pids="$(pgrep -f "minikube tunnel -p ${PROFILE}" || true)"
  fi
  if [[ -n "${pids}" ]]; then
    log "Tunnel running (PID(s)=${pids})"
  else
    log "Tunnel not running"
  fi
  return 0
}

tunnel_stop() {
  if [[ "${TUNNEL_ENABLED}" != "true" ]]; then
    log "Tunnel disabled via TUNNEL_ENABLED=false; nothing to stop."
    return 0
  fi
  if [[ -f "${TUNNEL_PIDFILE}" ]]; then
    local pid; pid="$(cat "${TUNNEL_PIDFILE}")"
    if [[ -n "${pid}" ]]; then
      log "Stopping tunnel (PID=${pid})"
      if command -v sudo >/dev/null 2>&1; then
        sudo kill "${pid}" 2>/dev/null || true
      else
        kill "${pid}" 2>/dev/null || true
      fi
    fi
    rm -f "${TUNNEL_PIDFILE}"
  fi
  # Fallback: kill any residual tunnel for this profile
  local pids; pids="$(pgrep -f "minikube tunnel -p ${PROFILE}" || true)"
  if [[ -n "${pids}" ]]; then
    log "Stopping remaining tunnel processes: ${pids}"
    if command -v sudo >/dev/null 2>&1; then
      sudo pkill -f "minikube tunnel -p ${PROFILE}" || true
    else
      pkill -f "minikube tunnel -p ${PROFILE}" || true
    fi
  fi
}

# Qdrant (Vector DB) helpers
qdrant_start_bg() {
  if [[ "${QDRANT_ENABLED}" != "true" ]]; then
    log "Qdrant integration disabled"
    return 0
  fi
  # Start qdrant in background if not running
  local running
  running="$(docker inspect -f '{{.State.Running}}' "${QDRANT_CONTAINER}" 2>/dev/null || echo "false")"
  if [[ "${running}" == "true" ]]; then
    log "Qdrant already running (container=${QDRANT_CONTAINER})"
    return 0
  fi
  if docker ps -a --filter "name=^/${QDRANT_CONTAINER}$" --format '{{.Names}}' | grep -qx "${QDRANT_CONTAINER}"; then
    log "Starting existing Qdrant container (${QDRANT_CONTAINER})..."
    docker start "${QDRANT_CONTAINER}" >/dev/null 2>&1 || true
  else
    log "Running Qdrant container in background: ${QDRANT_IMAGE} (port ${QDRANT_PORT})"
    docker run -d --name "${QDRANT_CONTAINER}" -p "${QDRANT_PORT}:${QDRANT_PORT}" "${QDRANT_IMAGE}" >/dev/null 2>&1 || true
  fi
  local status; status="$(docker inspect -f '{{.State.Status}}' "${QDRANT_CONTAINER}" 2>/dev/null || echo "unknown")"
  log "Qdrant started. Status: ${status}"
}

qdrant_status() {
  if [[ "${QDRANT_ENABLED}" != "true" ]]; then
    log "Qdrant integration disabled"
    return 0
  fi
  local status
  status="$(docker inspect -f '{{.State.Status}}' "${QDRANT_CONTAINER}" 2>/dev/null || true)"
  if [[ "${status}" == "running" ]]; then
    local cid; cid="$(docker ps --filter "name=^/${QDRANT_CONTAINER}$" --format '{{.ID}}' | head -n1)"
    log "Qdrant status: running (container=${QDRANT_CONTAINER}, id=${cid}, port=${QDRANT_PORT})"
  elif [[ -n "${status}" ]]; then
    log "Qdrant status: ${status} (container=${QDRANT_CONTAINER})"
  else
    log "Qdrant status: not found"
  fi
  return 0
}

qdrant_stop() {
  if [[ "${QDRANT_ENABLED}" != "true" ]]; then
    log "Qdrant integration disabled"
    return 0
  fi
  if docker ps -a --filter "name=^/${QDRANT_CONTAINER}$" --format '{{.Names}}' | grep -qx "${QDRANT_CONTAINER}"; then
    local status; status="$(docker inspect -f '{{.State.Status}}' "${QDRANT_CONTAINER}" 2>/dev/null || true)"
    if [[ "${status}" == "running" ]]; then
      log "Stopping Qdrant container (${QDRANT_CONTAINER})..."
      docker stop "${QDRANT_CONTAINER}" >/dev/null 2>&1 || true
      log "Qdrant stopped."
    else
      log "Qdrant not running (status=${status:-unknown})."
    fi
  else
    log "Qdrant container not present (${QDRANT_CONTAINER})."
  fi
}
 
pf_all_start() {
  : > "${PF_PIDFILE}"
  # For each service, forward first port (port:port)
  local lines; lines="$(kubectl -n "${NAMESPACE}" get svc -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .spec.ports[0:1]}{.port}{"\n"}{end}{end}' 2>/dev/null || true)"
  local count=0
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    local name="${line%%|*}"
    local port="${line##*|}"
    [[ -z "${port}" || ! "${port}" =~ ^[0-9]+$ ]] && continue
    nohup kubectl -n "${NAMESPACE}" port-forward "svc/${name}" "${port}:${port}" --address 0.0.0.0 >/dev/null 2>&1 &
    echo $! >> "${PF_PIDFILE}"
    log "Port-forward: ${name} ${port}->${port} (PID=$!)"
    count=$((count+1))
  done <<< "${lines}"
  log "Started ${count} port-forward(s) in namespace '${NAMESPACE}'. PIDs tracked in ${PF_PIDFILE}"
}

pf_all_status() {
  if [[ -f "${PF_PIDFILE}" ]]; then
    while IFS= read -r pid; do
      [[ -z "${pid}" ]] && continue
      if kill -0 "${pid}" 2>/dev/null; then
        log "Port-forward running (PID=${pid})"
      else
        log "Port-forward not running (PID=${pid})"
      fi
    done < "${PF_PIDFILE}"
  else
    log "No port-forward PID file (${PF_PIDFILE})."
  fi
  return 0
}

pf_all_stop() {
  if [[ -f "${PF_PIDFILE}" ]]; then
    log "Stopping port-forwards from ${PF_PIDFILE}..."
    while IFS= read -r pid; do
      [[ -z "${pid}" ]] && continue
      if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null || true
        log "Stopped PID ${pid}"
      fi
    done < "${PF_PIDFILE}"
    rm -f "${PF_PIDFILE}"
  else
    log "No port-forwards to stop."
  fi
}

cmd_start() {
  deps
  start_minikube_resilient

  dashboard_start_bg
  tunnel_start_bg
  pf_all_start
  qdrant_start_bg
 
  log "Start complete. Use './scripts/minikube_dev.sh status' to verify."
}

cmd_status() {
  deps
  log "Minikube status (profile=${PROFILE}):"
  minikube status -p "${PROFILE}" || true
  echo
  log "Kubectl context:"
  kubectl config current-context || true
  echo
  log "Nodes:"
  kubectl get nodes -o wide || true
  echo
  log "Namespace services (${NAMESPACE}):"
  kubectl -n "${NAMESPACE}" get svc || true
  echo
  log "Namespace pods (${NAMESPACE}):"
  kubectl -n "${NAMESPACE}" get pods -o wide || true
  echo
  dashboard_status
  tunnel_status
  pf_all_status
  qdrant_status
}

cmd_stop() {
  deps
  log "Stopping dev helpers (port-forwards, dashboard, tunnel, qdrant)..."
  pf_all_stop
  dashboard_stop
  tunnel_stop
  qdrant_stop

  log "Stopping Minikube (profile=${PROFILE})..."
  minikube stop -p "${PROFILE}" || true
  log "Stopped."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") {start|status|stop}

Commands:
  start   Start Minikube, dashboard (bg), tunnel (bg), and port-forward all services in ${NAMESPACE}
  status  Show cluster, services, dashboard/tunnel/port-forward status
  stop    Stop port-forwards, dashboard, tunnel, then stop Minikube

Env:
  MINIKUBE_PROFILE (default: ${PROFILE})
  NAMESPACE (default: ${NAMESPACE})
  PF_PIDFILE (default: ${PF_PIDFILE})
  DASH_PIDFILE (default: ${DASH_PIDFILE})
  TUNNEL_PIDFILE (default: ${TUNNEL_PIDFILE})
EOF
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    start)  cmd_start ;;
    status) cmd_status ;;
    stop)   cmd_stop ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"