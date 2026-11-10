# Kubernetes on-premise (kind + Kubernetes Goat)

Clúster Kubernetes local de NubloPost dentro de la VM `nublopost-onprem`, con Kubernetes Goat como carga de trabajo vulnerable. Kubernetes Goat no se copia al repositorio: `lab.sh` descarga el repositorio oficial y lo fija en un commit concreto.

## Versiones

| Componente | Versión | Cómo se fija |
|---|---|---|
| kind | v0.33.0 | Playbook de Ansible (`--tags k8s`), con el SHA-256 oficial comprobado |
| kubectl | v1.37.2 | Ídem; misma versión menor que el clúster |
| Helm | v4.3.1 | Ídem |
| Nodo (Kubernetes) | v1.37.0 | Imagen `kindest/node` fijada por digest en `kind-config.yaml` |
| Kubernetes Goat | commit `723a0db` (`master`, 17/04/2026) | `GOAT_COMMIT` en `lab.sh` |

Se usa un commit de `master` en lugar de la última versión etiquetada (v2.3.0, de septiembre de 2024) porque los commits posteriores adaptan el escenario `health-check` a clústeres con containerd, como kind.

## Uso

Dentro de la VM, con tu usuario y sin `sudo`:

```bash
cd ~/cloud-security-assessment/onprem/kubernetes
./lab.sh up       # crea el clúster y despliega Kubernetes Goat (la primera vez, 5-10 min)
./lab.sh access   # abre los escenarios en 127.0.0.1:1230-1236 de la VM
./lab.sh status   # nodos y pods
./lab.sh stop     # cierra los puertos
./lab.sh down     # borra el clúster
```

Si algo se queda a medias, `./lab.sh down` seguido de `./lab.sh up` lo deja como nuevo.

## Acceso desde Windows

Los escenarios solo escuchan en `127.0.0.1` dentro de la VM. Desde Windows se llega con un túnel SSH. Se añade esta entrada a `~/.ssh/config` (mismo usuario y clave que `Host onprem`):

```
Host onprem-goat
    HostName 127.0.0.1
    Port 2222
    User <usuario>
    IdentityFile ~/.ssh/nublopost_onprem
    ExitOnForwardFailure yes
    LocalForward 1230 127.0.0.1:1230
    LocalForward 1231 127.0.0.1:1231
    LocalForward 1232 127.0.0.1:1232
    LocalForward 1233 127.0.0.1:1233
    LocalForward 1234 127.0.0.1:1234
    LocalForward 1235 127.0.0.1:1235
    LocalForward 1236 127.0.0.1:1236
```

Con `ssh -N onprem-goat` abierto en una ventana de PowerShell, el portal queda en <http://127.0.0.1:1234>.

| Puerto | Escenario |
|---|---|
| 1230 | `build-code`: claves sensibles en el código |
| 1231 | `health-check`: socket del runtime de contenedores (DIND) |
| 1232 | `internal-proxy`: SSRF dentro del clúster |
| 1233 | `system-monitor`: escape del contenedor al nodo |
| 1234 | Portal de Kubernetes Goat |
| 1235 | `poor-registry`: registro privado de imágenes |
| 1236 | `hunger-check`: agotamiento de recursos (DoS) |

## Selección para el informe (Día 12)

Se despliegan todos los escenarios, pero el informe se centra en los que cubren los objetivos de Kubernetes del proyecto:

| Área | Escenarios |
|---|---|
| RBAC | `insecure-rbac` (cuenta de servicio con permisos de administrador) |
| Secrets | `build-code` y los Secrets del clúster; en el Día 4, el Secret del pod `api-test-client` (cadena on-prem → cloud) |
| Contenedores privilegiados | `system-monitor`, `health-check` |
| Network Policies | `cache-store` (aislamiento entre namespaces) |

Si en el checkpoint del Día 7 hay que recortar, se quedan RBAC, Secrets y un contenedor privilegiado.

El CNI de kind (kindnet) aplica las Network Policies, así que el TO-BE de esa área se puede demostrar sin instalar otro CNI.

## Controles del laboratorio

- **API server** solo en `127.0.0.1:6443` de la VM.
- **Port-forwards solo en `127.0.0.1`.** El script oficial `access-kubernetes-goat.sh` los abre en `0.0.0.0` (todas las interfaces), así que no se usa; lo sustituye `./lab.sh access`.
- **Sin puertos hacia la red:** VirtualBox en NAT; del portátil solo llega el SSH (`127.0.0.1:2222`).
- **La frontera de aislamiento es la VM:** los nodos de kind son contenedores privilegiados y varios escenarios montan rutas del nodo. Snapshot antes de cada sesión de pruebas.
- **Imágenes de Docker Hub sin autenticar:** límite de 100 descargas cada 6 horas por IP; un despliegue completo usa unas 15.

## Notas para el informe

- **Cadena de suministro:** versiones fijadas, SHA-256 comprobado en cada descarga y nodo fijado por digest. Mejora TO-BE: fijar también los hashes en el repositorio o verificar las firmas (cosign en Kubernetes, GPG en Helm), porque binario y checksum salen del mismo servidor.
- **Imágenes sin versión:** los manifiestos de Kubernetes Goat usan imágenes sin etiqueta (`latest`), que los escáneres marcarán como hallazgo.
- **Exposición por defecto:** el script de acceso oficial publica los escenarios en todas las interfaces; aquí se corrige con `lab.sh`.

## Problemas típicos

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Pods en `ImagePullBackOff` | Fallo al descargar imágenes (red o límite de Docker Hub) | Esperar unos minutos y repetir `./lab.sh up` |
| Errores `too many open files` | Límites de inotify | Ejecutar el playbook con `--tags k8s` (los sube) |
| `permission denied` al usar Docker | Sesión abierta antes de entrar en el grupo `docker` | Salir y volver a entrar por SSH |
| `ssh -N onprem-goat` falla al abrir los puertos | Otra ventana con el mismo túnel abierto | Cerrar la otra ventana |
