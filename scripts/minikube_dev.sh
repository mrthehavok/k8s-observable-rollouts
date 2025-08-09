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

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
err() { printf '[%s] ERROR: %s\n' "$(date -Is)" "$*" >&2; }
die() { err "$*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

deps() {
  need minikube
  need kubectl
}

dashboard_start_bg() {
  # Get URL (non-blocking) and open if possible, then run dashboard in bg for proxy
  local url
  url="$(minikube dashboard -p "${PROFILE}" --url 2>/dev/null || true)"
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
  if [[ -f "${DASH_PIDFILE}" ]]; then
    local pid; pid="$(cat "${DASH_PIDFILE}")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      log "Dashboard process running (PID=${pid})"
    else
      log "Dashboard process not running (PID file present but stale)"
    fi
  else
    log "Dashboard PID file not found (might still be running via other session)"
  fi
  local url; url="$(minikube dashboard -p "${PROFILE}" --url 2>/dev/null || true)"
  [[ -n "${url}" ]] && log "Dashboard URL: ${url}"
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
  # Will require sudo; if not cached, prompts once.
  log "Starting minikube tunnel in background (may prompt for sudo)..."
  # Start in background and record the wrapper PID; also try to capture actual tunnel PID later
  if command -v sudo >/dev/null 2>&1; then
    sudo -E nohup minikube tunnel -p "${PROFILE}" >/dev/null 2>&1 &
    echo $! > "${TUNNEL_PIDFILE}"
    sleep 1
    # Attempt to find actual tunnel PID owned by root
    local tpid; tpid="$(pgrep -f "minikube tunnel -p ${PROFILE}" | head -n1 || true)"
    if [[ -n "${tpid}" ]]; then
      echo "${tpid}" > "${TUNNEL_PIDFILE}"
    fi
    log "Tunnel started (PID=$(cat "${TUNNEL_PIDFILE}"))"
  else
    die "sudo is required to run minikube tunnel"
  fi
}

tunnel_status() {
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
}

tunnel_stop() {
  if [[ -f "${TUNNEL_PIDFILE}" ]]; then
    local pid; pid="$(cat "${TUNNEL_PIDFILE}")"
    if [[ -n "${pid}" ]]; then
      log "Stopping tunnel (PID=${pid})"
      sudo kill "${pid}" 2>/dev/null || true
    fi
    rm -f "${TUNNEL_PIDFILE}"
  fi
  # Fallback: kill any residual tunnel for this profile
  local pids; pids="$(pgrep -f "minikube tunnel -p ${PROFILE}" || true)"
  if [[ -n "${pids}" ]]; then
    log "Stopping remaining tunnel processes: ${pids}"
    sudo pkill -f "minikube tunnel -p ${PROFILE}" || true
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
  log "Starting Minikube (profile=${PROFILE})..."
  minikube start -p "${PROFILE}" --wait=all
  log "Minikube started."

  dashboard_start_bg
  tunnel_start_bg
  pf_all_start

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
}

cmd_stop() {
  deps
  log "Stopping dev helpers (port-forwards, dashboard, tunnel)..."
  pf_all_stop
  dashboard_stop
  tunnel_stop

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