#!/usr/bin/env bash
set -euo pipefail

# Simple Minikube dev control script: start | status | stop
# - start: starts Minikube, Dashboard (bg), Tunnel (bg), Argo CD port-forward (bg), optional Qdrant
# - status: shows cluster health and access URLs
# - stop: stops port-forwards, dashboard, tunnel, qdrant, and Minikube

# Defaults
PROFILE="${MINIKUBE_PROFILE:-minikube}"
NAMESPACE="${NAMESPACE:-sample-app}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

# Minikube settings
K8S_VERSION="${K8S_VERSION:-v1.33.1}"
MEMORY="${MEMORY:-8192}"
CPUS="${CPUS:-4}"
DISK_SIZE="${DISK_SIZE:-20g}"
DRIVER="${DRIVER:-docker}"

# Runtime artifacts
DASH_PIDFILE=".minikube-dashboard.pid"
TUNNEL_PIDFILE=".minikube-tunnel.pid"
ARGOCD_PF_PIDFILE=".minikube-argocd.pid"

# Qdrant settings (optional)
QDRANT_IMAGE="${QDRANT_IMAGE:-qdrant/qdrant}"
QDRANT_CONTAINER="${QDRANT_CONTAINER:-qdrant-dev}"
QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_ENABLED="${QDRANT_ENABLED:-true}"

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
err() { printf '[%s] ERROR: %s\n' "$(date -Is)" "$*" >&2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

start_minikube() {
  log "Disabling potentially problematic addons..."
  minikube addons disable registry -p "${PROFILE}" || true
  minikube addons disable storage-provisioner -p "${PROFILE}" || true

  log "Starting Minikube (profile=${PROFILE})..."
  minikube start \
    -p "${PROFILE}" \
    --driver="${DRIVER}" \
    --kubernetes-version="${K8S_VERSION}" \
    --memory="${MEMORY}" \
    --cpus="${CPUS}" \
    --disk-size="${DISK_SIZE}" \
    --container-runtime=containerd \
    --addons=ingress,metrics-server,dashboard \
    --extra-config=kubelet.housekeeping-interval=10s

  # Wait for nodes (best-effort)
  kubectl wait --for=condition=ready nodes --all --timeout=300s >/dev/null 2>&1 || true
  log "Minikube start attempted. Health check:"
  minikube status -p "${PROFILE}" || true
}

start_dashboard_bg() {
  log "Starting Kubernetes Dashboard in background..."
  nohup minikube dashboard -p "${PROFILE}" >/dev/null 2>&1 &
  echo $! > "${DASH_PIDFILE}"
  log "Dashboard PID=$(cat "${DASH_PIDFILE}")"
}

start_tunnel_bg() {
  log "Starting Minikube tunnel in background..."
  if have_cmd sudo && sudo -n true 2>/dev/null; then
    nohup sudo -E minikube tunnel -p "${PROFILE}" >/dev/null 2>&1 &
  else
    nohup minikube tunnel -p "${PROFILE}" >/dev/null 2>&1 &
  fi
  echo $! > "${TUNNEL_PIDFILE}"
  log "Tunnel PID=$(cat "${TUNNEL_PIDFILE}")"
}

start_argocd_pf_bg() {
  if ! kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
    log "Argo CD namespace '${ARGOCD_NAMESPACE}' not found; skipping port-forward."
    return 0
  fi
  if ! kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server >/dev/null 2>&1; then
    log "Argo CD service not found; skipping port-forward."
    return 0
  fi
  log "Starting Argo CD port-forward 127.0.0.1:8080 -> ${ARGOCD_NAMESPACE}/argocd-server:443 ..."
  nohup kubectl -n "${ARGOCD_NAMESPACE}" port-forward svc/argocd-server 8080:443 >/dev/null 2>&1 &
  echo $! > "${ARGOCD_PF_PIDFILE}"
  log "Argo CD port-forward PID=$(cat "${ARGOCD_PF_PIDFILE}")"
}

start_qdrant_bg() {
  if [[ "${QDRANT_ENABLED}" != "true" ]]; then
    log "Qdrant disabled (QDRANT_ENABLED=false)."
    return 0
  fi
  if ! have_cmd docker; then
    err "docker not found; skipping Qdrant."
    return 0
  fi
  # Ensure no old container is lingering
  if docker ps -a --format '{{.Names}}' | grep -qx "${QDRANT_CONTAINER}"; then
    log "Removing existing Qdrant container..."
    docker rm -f "${QDRANT_CONTAINER}" >/dev/null
  fi
  log "Running Qdrant container: ${QDRANT_IMAGE} (port ${QDRANT_PORT})"
  docker run -d --name "${QDRANT_CONTAINER}" -p "${QDRANT_PORT}:${QDRANT_PORT}" "${QDRANT_IMAGE}" >/dev/null
}

get_dashboard_url() {
  local url
  url="$(minikube dashboard -p "${PROFILE}" --url 2>/dev/null || true)"
  echo "${url}"
}

get_argocd_url() {
  # Prefer port-forward URL if running
  if [[ -f "${ARGOCD_PF_PIDFILE}" ]] && kill -0 "$(cat "${ARGOCD_PF_PIDFILE}" 2>/dev/null || echo 0)" 2>/dev/null; then
    echo "https://127.0.0.1:8080"
    return 0
  fi
  # Try LoadBalancer IP/hostname
  if kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server >/dev/null 2>&1; then
    local ip host
    ip="$(kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    host="$(kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ -n "${ip}" ]]; then echo "https://${ip}"; return 0; fi
    if [[ -n "${host}" ]]; then echo "https://${host}"; return 0; fi
  fi
  echo ""
}

cmd_start() {
  start_minikube
  start_dashboard_bg
  start_tunnel_bg
  start_argocd_pf_bg
  start_qdrant_bg

  # Access summary (print at the very end)
  local mk_ip dash_url argocd_url
  mk_ip="$(minikube ip -p "${PROFILE}" 2>/dev/null || true)"
  dash_url="$(get_dashboard_url)"
  argocd_url="$(get_argocd_url)"
  echo ""
  log "Access:"
  [[ -n "${mk_ip}" ]] && log "Minikube IP - ${mk_ip}"
  if [[ -n "${dash_url}" ]]; then
    log "Dashboard - ${dash_url}"
  else
    log "Dashboard - preparing (try again in a few seconds)"
  fi
  if [[ -n "${argocd_url}" ]]; then
    log "Argo CD - ${argocd_url}"
  else
    log "Argo CD - not available yet"
  fi
}

cmd_status() {
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
  # PIDs
  if [[ -f "${DASH_PIDFILE}" ]] && kill -0 "$(cat "${DASH_PIDFILE}" 2>/dev/null || echo 0)" 2>/dev/null; then
    log "Dashboard running (PID=$(cat "${DASH_PIDFILE}") )"
  else
    log "Dashboard not running"
  fi
  if [[ -f "${TUNNEL_PIDFILE}" ]] && kill -0 "$(cat "${TUNNEL_PIDFILE}" 2>/dev/null || echo 0)" 2>/dev/null; then
    log "Tunnel running (PID=$(cat "${TUNNEL_PIDFILE}") )"
  else
    log "Tunnel not running"
  fi
  if [[ -f "${ARGOCD_PF_PIDFILE}" ]] && kill -0 "$(cat "${ARGOCD_PF_PIDFILE}" 2>/dev/null || echo 0)" 2>/dev/null; then
    log "Argo CD port-forward running (PID=$(cat "${ARGOCD_PF_PIDFILE}") )"
  else
    log "Argo CD port-forward not running"
  fi
  if have_cmd docker; then
    local qstatus
    qstatus="$(docker inspect -f '{{.State.Status}}' "${QDRANT_CONTAINER}" 2>/dev/null || echo "")"
    if [[ -n "${qstatus}" ]]; then
      log "Qdrant container status: ${qstatus}"
    else
      log "Qdrant container: not present"
    fi
  fi
  echo
  # URLs
  local dash_url argocd_url mk_ip
  mk_ip="$(minikube ip -p "${PROFILE}" 2>/dev/null || true)"
  dash_url="$(get_dashboard_url)"
  argocd_url="$(get_argocd_url)"
  log "Access:"
  [[ -n "${mk_ip}" ]] && log "Minikube IP - ${mk_ip}"
  [[ -n "${dash_url}" ]] && log "Dashboard - ${dash_url}" || log "Dashboard - unavailable"
  [[ -n "${argocd_url}" ]] && log "Argo CD - ${argocd_url}" || log "Argo CD - unavailable"
}

cmd_stop() {
  log "Stopping dev helpers..."
  # dashboard
  if [[ -f "${DASH_PIDFILE}" ]]; then
    pid="$(cat "${DASH_PIDFILE}" 2>/dev/null || echo "")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      log "Stopped dashboard (PID=${pid})"
    fi
    rm -f "${DASH_PIDFILE}"
  fi
  # tunnel
  if [[ -f "${TUNNEL_PIDFILE}" ]]; then
    pid="$(cat "${TUNNEL_PIDFILE}" 2>/dev/null || echo "")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      if have_cmd sudo; then sudo kill "${pid}" 2>/dev/null || true; else kill "${pid}" 2>/dev/null || true; fi
      log "Stopped tunnel (PID=${pid})"
    fi
    rm -f "${TUNNEL_PIDFILE}"
  fi
  # argocd pf
  if [[ -f "${ARGOCD_PF_PIDFILE}" ]]; then
    pid="$(cat "${ARGOCD_PF_PIDFILE}" 2>/dev/null || echo "")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      log "Stopped Argo CD port-forward (PID=${pid})"
    fi
    rm -f "${ARGOCD_PF_PIDFILE}"
  fi
  # qdrant
  if [[ "${QDRANT_ENABLED}" == "true" ]] && have_cmd docker; then
    if docker ps -a --format '{{.Names}}' | grep -qx "${QDRANT_CONTAINER}"; then
      log "Stopping and removing Qdrant container (${QDRANT_CONTAINER})..."
      docker rm -f "${QDRANT_CONTAINER}" >/dev/null 2>&1 || true
    fi
  fi
  # minikube
  log "Stopping Minikube (profile=${PROFILE})..."
  minikube stop -p "${PROFILE}" || true
  log "Stopped."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") {start|status|stop}

Commands:
  start   Start Minikube, Dashboard (bg), Tunnel (bg), Argo CD port-forward (bg), and optional Qdrant
  status  Show cluster health and access URLs
  stop    Stop background helpers and Minikube

Env:
  MINIKUBE_PROFILE (default: ${PROFILE})
  NAMESPACE (default: ${NAMESPACE})
  ARGOCD_NAMESPACE (default: ${ARGOCD_NAMESPACE})
  K8S_VERSION (default: ${K8S_VERSION})
  MEMORY (default: ${MEMORY})
  CPUS (default: ${CPUS})
  DISK_SIZE (default: ${DISK_SIZE})
  DRIVER (default: ${DRIVER})
  QDRANT_ENABLED (default: ${QDRANT_ENABLED})
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