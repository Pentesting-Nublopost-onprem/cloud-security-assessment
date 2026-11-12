# Servidor on-premise (Ubuntu Server 24.04)

Servidor "on-premise" de NubloPost: una VM en VirtualBox que aloja Docker y, a partir del Día 3, el clúster Kubernetes local.

## Máquina virtual (VirtualBox)

| Parámetro | Valor |
|---|---|
| Nombre | `nublopost-onprem` |
| Sistema | Ubuntu Server 24.04 LTS (64-bit) |
| CPU | 2–4 vCPU |
| RAM | 8 GB |
| Disco | 80 GB, VDI de tamaño dinámico |
| Red | Adaptador 1 en NAT, con reenvío de puertos SSH `127.0.0.1:2222 → 22` |

El reenvío de puertos se limita a `127.0.0.1`: al servidor solo se puede conectar desde el propio portátil, no desde la red local.

## Instalación de Ubuntu

- Instalación manual (sin la instalación desatendida de VirtualBox).
- Almacenamiento: todo el disco; el volumen raíz (`ubuntu-lv`) debe ocupar todo el espacio.
- Nombre del servidor: `nublopost-onprem`.
- OpenSSH server instalado; sin snaps adicionales (Docker se instala con el playbook desde el repositorio oficial).

## Acceso por SSH desde Windows

Clave dedicada para el laboratorio y alias `onprem` en `~/.ssh/config`:

```
Host onprem
    HostName 127.0.0.1
    Port 2222
    User <usuario>
    IdentityFile ~/.ssh/nublopost_onprem
```

## Configuración con Ansible

Ansible se ejecuta dentro de la propia VM, contra `localhost`:

```bash
sudo apt update && sudo apt install -y ansible git
git clone https://github.com/Pentesting-Nublopost-onprem/cloud-security-assessment.git
cd cloud-security-assessment/onprem/ansible
ansible-playbook -i inventory.ini site.yml -K
```

Cuando el acceso por clave funcione, se desactivan las contraseñas:

```bash
ansible-playbook -i inventory.ini site.yml -K -e harden_ssh=true
```

Para instalar o actualizar solo las herramientas de Kubernetes:

```bash
ansible-playbook -i inventory.ini site.yml -K --tags k8s
```

### Qué hace el playbook

- Paquetes base, zona horaria `Europe/Madrid` (marcas de tiempo coherentes en las evidencias) y actualizaciones de seguridad automáticas.
- Docker Engine desde el repositorio oficial; añade el usuario al grupo `docker`.
- kind, kubectl y Helm en versiones fijadas, con autocompletado de bash y los límites de inotify que recomienda kind (detalle abajo).
- Con `harden_ssh=true`: SSH solo con clave y sin acceso de root. Se para si el usuario no tiene ninguna clave autorizada, para no dejarte fuera.

### Herramientas de Kubernetes

| Herramienta | Versión | Origen |
|---|---|---|
| kind | v0.33.0 | Publicación oficial en GitHub (`kubernetes-sigs/kind`) |
| kubectl | v1.37.2 | `dl.k8s.io` |
| Helm | v4.3.1 | `get.helm.sh` |

Cada binario se descarga junto con su SHA-256 oficial; si no coincide, la tarea falla y no se instala nada. Para cambiar de versión basta con editar `kind_version`, `kubectl_version` o `helm_version` en `site.yml`: el checksum de la nueva versión se descarga solo. Helm se guarda por versión en `/opt/helm/` y `/usr/local/bin/helm` apunta a la activa. El clúster y Kubernetes Goat se gestionan con `onprem/kubernetes/lab.sh`.

## Nota de seguridad

Pertenecer al grupo `docker` equivale a tener privilegios de root en el servidor. Se acepta en el laboratorio por comodidad y se documenta como hallazgo del servidor on-premise (TO-BE: Docker en modo rootless o uso explícito de `sudo`).
