#!/usr/bin/env bash
set -euo pipefail

# Unified dev control script: deploy | start | status | stop
# - deploy: setup Minikube and Argo CD (App-of-Apps), then start helpers
# - start: ensure cluster is up and start helpers (no redeploy)
# - status: show cluster health and access URLs
# - stop: stop helpers and Minikube

# Profile and namespaces
PROFILE="${MINIKUBE_PROFILE:-minikube}"
NAMESPACE="${NAMESPACE:-sample-app}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

# Minikube settings
K8S_VERSION="${K8S_VERSION:-v1.33.1}"
MEMORY="${MEMORY:-8192}"
CPUS="${CPUS:-4}"
DISK_SIZE="${DISK_SIZE:-20g}"
DRIVER="${DRIVER:-docker}"

# Argo CD settings
ARGOCD_HELM_VERSION="${ARGOCD_VERSION:-8.2.2}"
ARGOCD_VALUES_FILE="${ARGOCD_VALUES_FILE:-infrastructure/argocd/values.yaml}"
APP_OF_APPS_FILE="${APP_OF_APPS_FILE:-infrastructure/argocd/applications/app-of-apps.yaml}"

# Optional reset on deploy (delete existing cluster)
RESET_CLUSTER="${RESET_CLUSTER:-false}"

# Runtime artifacts (PID files)
DASH_PIDFILE=".minikube-dashboard.pid"
TUNNEL_PIDFILE=".minikube-tunnel.pid"
ARGOCD_PF_PIDFILE=".minikube-argocd.pid"

# Qdrant optional
QDRANT_IMAGE="${QDRANT_IMAGE:-qdrant/qdrant}"
QDRANT_CONTAINER="${QDRANT_CONTAINER:-qdrant-dev}"
QDRANT_PORT="${QDRANT_PORT:-6333}"
QDRANT_ENABLED="${QDRANT_ENABLED:-true}"

# Argo CD port-forward port
ARGOPF_PORT="${ARGOPF_PORT:-8080}"

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
err() { printf '[%s] ERROR: %s\n' "$(date -Is)" "$*" >&2; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

port_in_use() {
  local port="$1"
  if have_cmd ss; then
    ss -ltn "( sport = :${port} )" | tail -n +2 | grep -q .
    return $?
  elif have_cmd lsof; then
    lsof -iTCP -sTCP:LISTEN -n -P | awk '{print $9}' | grep -q ":${port}$"
    return $?
  elif have_cmd nc; then
    nc -z localhost "${port}" >/dev/null 2>&1
    return $?
  else
    return 1
  fi
}

start_minikube_core() {
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

  log "Waiting for nodes to be ready..."
  kubectl wait --for=condition=ready nodes --all --timeout=300s || true

  log "Enabling additional addons..."
  minikube addons enable registry -p "${PROFILE}" || true
  minikube addons enable storage-provisioner -p "${PROFILE}" || true

  log "Waiting for NGINX Ingress controller..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s || true
}

post_cluster_bootstrap() {
  log "Creating namespaces..."
  kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

  log "Labeling namespaces for monitoring..."
  kubectl label namespace "${ARGOCD_NAMESPACE}" monitoring=enabled --overwrite
  kubectl label namespace "${NAMESPACE}" monitoring=enabled --overwrite
  kubectl label namespace default monitoring=enabled --overwrite

  log "Configuring local registry hosting hint..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

install_argocd() {
  log "Adding Argo Helm repo..."
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo update

  log "Installing/Upgrading Argo CD (chart v${ARGOCD_HELM_VERSION})..."
  helm upgrade --install argocd argo/argo-cd \
    --namespace "${ARGOCD_NAMESPACE}" \
    --version "${ARGOCD_HELM_VERSION}" \
    --values "${ARGOCD_VALUES_FILE}" \
    --wait

  log "Waiting for Argo CD components to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=300s
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s

  log "Applying Argo CD custom configuration..."
  kubectl apply -f infrastructure/argocd/config/

  log "Applying App of Apps..."
  kubectl apply -f "${APP_OF_APPS_FILE}"

  log "Retrieving Argo CD initial admin password..."
  ARGOCD_PASSWORD="$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
  if [[ -n "${ARGOCD_PASSWORD}" ]]; then
    log "Argo CD admin password acquired."
  else
    err "Failed to retrieve Argo CD admin password (secret may have rotated)."
  fi

  if ! have_cmd argocd; then
    log "Installing Argo CD CLI..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo chmod +x /tmp/argocd
    sudo mv /tmp/argocd /usr/local/bin/argocd
  fi

  # Start port-forward if available and port free, then login
  start_argocd_pf_bg
  if have_cmd argocd && [[ -n "${ARGOCD_PASSWORD:-}" ]]; then
    if port_in_use "${ARGOPF_PORT}"; then
      log "Port ${ARGOPF_PORT} busy; skipping argocd CLI login."
    else
      sleep 3
      argocd login "localhost:${ARGOPF_PORT}" --username admin --password "${ARGOCD_PASSWORD}" --insecure --plaintext || true
    fi
  fi
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
  if port_in_use "${ARGOPF_PORT}"; then
    log "Port ${ARGOPF_PORT} is already in use; skipping Argo CD port-forward."
    return 0
  fi
  log "Starting Argo CD port-forward 127.0.0.1:${ARGOPF_PORT} -> ${ARGOCD_NAMESPACE}/argocd-server:443 ..."
  nohup kubectl -n "${ARGOCD_NAMESPACE}" port-forward svc/argocd-server "${ARGOPF_PORT}:443" >/dev/null 2>&1 &
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
  if [[ -f "${ARGOCD_PF_PIDFILE}" ]] && kill -0 "$(cat "${ARGOCD_PF_PIDFILE}" 2>/dev/null || echo 0)" 2>/dev/null; then
    echo "https://127.0.0.1:${ARGOPF_PORT}"
    return 0
  fi
  if kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server >/dev/null 2>&1; then
    local ip host
    ip="$(kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    host="$(kubectl -n "${ARGOCD_NAMESPACE}" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ -n "${ip}" ]]; then echo "https://${ip}"; return 0; fi
    if [[ -n "${host}" ]]; then echo "https://${host}"; return 0; fi
  fi
  echo ""
}

cmd_deploy() {
  if [[ "${RESET_CLUSTER}" == "true" ]]; then
    log "Reset requested. Deleting existing Minikube cluster (profile=${PROFILE})..."
    minikube delete -p "${PROFILE}" || true
  fi
  start_minikube_core
  post_cluster_bootstrap
  install_argocd
  start_dashboard_bg
  start_tunnel_bg
  start_qdrant_bg

  local mk_ip dash_url argocd_url
  mk_ip="$(minikube ip -p "${PROFILE}" 2>/dev/null || true)"
  dash_url="$(get_dashboard_url)"
  argocd_url="$(get_argocd_url)"
  echo ""
  log "Deploy complete. Access:"
  [[ -n "${mk_ip}" ]] && log "Minikube IP - ${mk_ip}"
  [[ -n "${dash_url}" ]] && log "Dashboard - ${dash_url}" || log "Dashboard - preparing"
  [[ -n "${argocd_url}" ]] && log "Argo CD - ${argocd_url}" || log "Argo CD - not available yet"
}

cmd_start() {
  log "Ensuring Minikube is running..."
  if ! minikube status -p "${PROFILE}" >/dev/null 2>&1; then
    start_minikube_core
    post_cluster_bootstrap
  else
    log "Minikube already running."
  fi
  start_dashboard_bg
  start_tunnel_bg
  start_argocd_pf_bg
  start_qdrant_bg

  local mk_ip dash_url argocd_url
  mk_ip="$(minikube ip -p "${PROFILE}" 2>/dev/null || true)"
  dash_url="$(get_dashboard_url)"
  argocd_url="$(get_argocd_url)"
  echo ""
  log "Access:"
  [[ -n "${mk_ip}" ]] && log "Minikube IP - ${mk_ip}"
  [[ -n "${dash_url}" ]] && log "Dashboard - ${dash_url}" || log "Dashboard - unavailable"
  [[ -n "${argocd_url}" ]] && log "Argo CD - ${argocd_url}" || log "Argo CD - unavailable"
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
  if [[ -f "${DASH_PIDFILE}" ]]; then
    pid="$(cat "${DASH_PIDFILE}" 2>/dev/null || echo "")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      log "Stopped dashboard (PID=${pid})"
    fi
    rm -f "${DASH_PIDFILE}"
  fi
  if [[ -f "${TUNNEL_PIDFILE}" ]]; then
    pid="$(cat "${TUNNEL_PIDFILE}" 2>/dev/null || echo "")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      if have_cmd sudo; then sudo kill "${pid}" 2>/dev/null || true; else kill "${pid}" 2>/dev/null || true; fi
      log "Stopped tunnel (PID=${pid})"
    fi
    rm -f "${TUNNEL_PIDFILE}"
  fi
  if [[ -f "${ARGOCD_PF_PIDFILE}" ]]; then
    pid="$(cat "${ARGOCD_PF_PIDFILE}" 2>/dev/null || echo "")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      log "Stopped Argo CD port-forward (PID=${pid})"
    fi
    rm -f "${ARGOCD_PF_PIDFILE}"
  fi
  if [[ "${QDRANT_ENABLED}" == "true" ]] && have_cmd docker; then
    if docker ps -a --format '{{.Names}}' | grep -qx "${QDRANT_CONTAINER}"; then
      log "Stopping and removing Qdrant container (${QDRANT_CONTAINER})..."
      docker rm -f "${QDRANT_CONTAINER}" >/dev/null 2>&1 || true
    fi
  fi
  log "Stopping Minikube (profile=${PROFILE})..."
  minikube stop -p "${PROFILE}" || true
  log "Stopped."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") {deploy|start|status|stop}

Commands:
  deploy  Create/ensure Minikube + Argo CD, apply App-of-Apps, then start helpers
  start   Ensure cluster is running, start helpers (no redeploy)
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
  ARGOCD_VERSION (default: ${ARGOCD_HELM_VERSION})
  ARGOCD_VALUES_FILE (default: ${ARGOCD_VALUES_FILE})
  APP_OF_APPS_FILE (default: ${APP_OF_APPS_FILE})
  ARGOPF_PORT (default: ${ARGOPF_PORT})
  RESET_CLUSTER (default: ${RESET_CLUSTER})
  QDRANT_ENABLED (default: ${QDRANT_ENABLED})
EOF
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    deploy) cmd_deploy ;;
    start)  cmd_start ;;
    status) cmd_status ;;
    stop)   cmd_stop ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"