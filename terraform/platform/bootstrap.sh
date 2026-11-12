#!/usr/bin/env bash
# Primer despliegue de la plataforma (solo una vez).
# Crea el Storage del estado con estado local y después migra el estado a ese Storage.
#
#   ./bootstrap.sh -var 'alert_email=tu@correo'
#
# Los argumentos se pasan tal cual a terraform apply.
set -euo pipefail
cd "$(dirname "$0")"

[ -f backend.tf ] || {
  echo "No encuentro backend.tf: ¿ya se hizo el bootstrap?" >&2
  exit 1
}

restore_backend() { if [ -f backend.tf.off ]; then mv backend.tf.off backend.tf; fi; }
trap restore_backend EXIT

# 1. Estado local: el Storage del estado todavía no existe.
mv backend.tf backend.tf.off
terraform init -input=false
terraform apply "$@"
storage_account="$(terraform output -raw state_storage_account)"
restore_backend

# 2. Migrar el estado al Storage. El permiso de datos recién asignado tarda
#    unos minutos en aplicarse, así que se reintenta.
echo "Migrando el estado a ${storage_account}..."
for attempt in $(seq 1 10); do
  if terraform init -input=false -migrate-state -force-copy \
    -backend-config="storage_account_name=${storage_account}"; then
    rm -f terraform.tfstate terraform.tfstate.backup
    echo
    echo "Listo. Para volver a usar esta raíz:"
    echo "  terraform init -backend-config=\"storage_account_name=${storage_account}\""
    exit 0
  fi
  echo "Aún sin permiso sobre el estado; reintento en 30 s (${attempt}/10)"
  sleep 30
done

echo "No se pudo migrar el estado. Repite este paso dentro de unos minutos:" >&2
echo "  terraform init -migrate-state -force-copy -backend-config=\"storage_account_name=${storage_account}\"" >&2
exit 1
