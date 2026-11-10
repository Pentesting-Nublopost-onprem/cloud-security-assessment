#!/usr/bin/env bash
# Laboratorio Kubernetes de NubloPost: clúster kind + Kubernetes Goat.
#
#   ./lab.sh up       crea el clúster (si no existe) y despliega Kubernetes Goat
#   ./lab.sh access   abre los escenarios en 127.0.0.1:1230-1236 de la VM
#   ./lab.sh stop     cierra esos puertos
#   ./lab.sh status   estado del clúster y de los pods
#   ./lab.sh down     borra el clúster entero
#
# Se ejecuta dentro de la VM con tu usuario, sin sudo.
set -euo pipefail

CLUSTER=nublopost
CONTEXT="kind-${CLUSTER}"

# Kubernetes Goat no se copia al repo: se usa el repositorio oficial en un commit fijo.
GOAT_REPO=https://github.com/madhuakula/kubernetes-goat.git
GOAT_COMMIT=723a0db478f050d173d23b4ce5044b65bce0bdd0 # rama master, 17/04/2026
GOAT_DIR="${HOME}/kubernetes-goat"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.nublopost-lab"
PID_FILE="${STATE_DIR}/port-forward.pids"

# namespace, deployment, puerto en la VM, puerto del pod
# (los mismos puertos que el script oficial access-kubernetes-goat.sh)
FORWARDS=(
  "default      build-code-deployment            1230 3000"
  "default      health-check-deployment          1231 80"
  "default      internal-proxy-deployment        1232 3000"
  "default      system-monitor-deployment        1233 8080"
  "default      kubernetes-goat-home-deployment  1234 80"
  "default      poor-registry-deployment         1235 5000"
  "big-monolith hunger-check-deployment          1236 8080"
)

log() { printf '\n==> %s\n' "$*"; }
die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

need() {
  [ "$(id -u)" -ne 0 ] || die "ejecútalo con tu usuario, sin sudo (kind guarda el acceso al clúster en tu \$HOME)"
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || die "no encuentro '${cmd}': ejecuta antes el playbook de Ansible (onprem/ansible, --tags k8s)"
  done
}

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; }

up() {
  need docker kind kubectl helm git
  docker info >/dev/null 2>&1 || die "Docker no responde con tu usuario: sal de la sesión SSH y vuelve a entrar (grupo docker)"

  if cluster_exists; then
    log "El clúster ${CLUSTER} ya existe"
  else
    log "Creando el clúster ${CLUSTER} (la primera vez descarga la imagen del nodo)"
    kind create cluster --config "${HERE}/kind-config.yaml"
  fi
  kubectl config use-context "$CONTEXT" >/dev/null
  kubectl wait --for=condition=Ready node --all --timeout=180s

  if [ ! -d "${GOAT_DIR}/.git" ]; then
    log "Descargando Kubernetes Goat"
    git clone --quiet "$GOAT_REPO" "$GOAT_DIR"
  fi
  git -C "$GOAT_DIR" cat-file -e "${GOAT_COMMIT}^{commit}" 2>/dev/null || git -C "$GOAT_DIR" fetch --quiet origin
  git -C "$GOAT_DIR" -c advice.detachedHead=false checkout --quiet "$GOAT_COMMIT"

  if helm status metadata-db >/dev/null 2>&1; then
    log "Kubernetes Goat ya está desplegado"
  else
    log "Desplegando Kubernetes Goat (commit ${GOAT_COMMIT:0:7})"
    (cd "$GOAT_DIR" && bash setup-kubernetes-goat.sh)
  fi

  log "Esperando a que arranquen los escenarios (la primera vez tarda unos minutos)"
  kubectl wait --for=condition=Available deployment --all --all-namespaces --timeout=15m ||
    die "hay escenarios sin arrancar: revisa 'kubectl get pods -A' (ImagePullBackOff = no se pudo descargar una imagen; espera y repite ./lab.sh up)"
  kubectl get pods --all-namespaces
  log "Listo. Siguiente paso: ./lab.sh access"
}

access() {
  need kubectl
  stop_access quiet
  mkdir -p "$STATE_DIR"
  log "Abriendo los escenarios en 127.0.0.1 (solo dentro de la VM)"
  local line ns deploy lport rport pid
  for line in "${FORWARDS[@]}"; do
    read -r ns deploy lport rport <<<"$line"
    kubectl --context "$CONTEXT" -n "$ns" rollout status "deployment/${deploy}" --timeout=10m >/dev/null
    nohup kubectl --context "$CONTEXT" -n "$ns" port-forward "deployment/${deploy}" \
      --address 127.0.0.1 "${lport}:${rport}" >"${STATE_DIR}/${deploy}.log" 2>&1 &
    echo "$!" >>"$PID_FILE"
    printf '  127.0.0.1:%s  ->  %s\n' "$lport" "$deploy"
  done
  sleep 3
  while read -r pid; do
    kill -0 "$pid" 2>/dev/null || die "algún port-forward se ha cerrado: mira los logs en ${STATE_DIR}"
  done <"$PID_FILE"
  log "Listo. En Windows: ssh -N onprem-goat y abre http://127.0.0.1:1234"
}

stop_access() {
  local pid
  if [ -f "$PID_FILE" ]; then
    while read -r pid; do kill "$pid" 2>/dev/null || true; done <"$PID_FILE"
    rm -f "$PID_FILE"
  fi
  [ "${1:-}" = quiet ] || log "Puertos de Kubernetes Goat cerrados"
}

status() {
  need kind kubectl
  if ! cluster_exists; then
    log "No hay clúster ${CLUSTER}: ejecuta ./lab.sh up"
    return 0
  fi
  kubectl --context "$CONTEXT" get nodes -o wide
  kubectl --context "$CONTEXT" get pods --all-namespaces
  if [ -f "$PID_FILE" ]; then
    log "Port-forwards abiertos: $(wc -l <"$PID_FILE")"
  fi
}

down() {
  need kind
  stop_access quiet
  kind delete cluster --name "$CLUSTER"
}

usage() { sed -n '4,8p' "$0" | sed 's/^# //'; }

case "${1:-}" in
  up) up ;;
  access) access ;;
  stop) stop_access ;;
  status) status ;;
  down) down ;;
  *)
    usage
    exit 1
    ;;
esac
