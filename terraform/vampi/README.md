# Raíz `vampi`

VAmPI (API REST vulnerable a propósito) en Azure Container Apps, dentro de `rg-vampi`.

| Recurso | Nombre | Notas |
|---|---|---|
| Log Analytics | `log-vampi` | 30 días de retención, tope de 0,5 GB/día |
| Entorno de Container Apps | `cae-vampi` | Plan Consumption, registros a Log Analytics |
| Container App | `ca-vampi` | 0,25 vCPU / 0,5 GiB, de 0 a 1 réplicas, imagen pública de GHCR |

## Exposición

- **Solo HTTPS:** las peticiones HTTP se redirigen.
- **Solo tu IP pública** (`allowed_ip`): cualquier otra recibe 403. La VM on-prem sale a Internet por la misma IP que tu portátil, así que el pod `api-test-client` también entra.
- Si tu IP de casa cambia, vuelve a aplicar con la nueva.

## Requisitos

1. Raíz `platform` desplegada.
2. Imagen publicada por el workflow `build-vampi` y paquete `vampi` de GHCR en **público** (Container Apps la descarga sin credenciales).

## Despliegue (Azure Cloud Shell)

```bash
cd cloud-security-assessment/terraform/vampi
SA=$(az storage account list -g rg-platform --query "[0].name" -o tsv)
terraform init -backend-config="storage_account_name=$SA"
terraform apply -var 'allowed_ip=<tu IP pública>'
```

Tu IP pública se consulta **desde tu PC** (no desde Cloud Shell, que sale por IPs de Azure): <https://ifconfig.me>.

La salida `vampi_url` es la URL para el pod `api-test-client` y para las pruebas de la API.

## Coste y limpieza

Con cero réplicas en reposo, el coste es casi nulo (Container Apps tiene una cuota gratuita mensual). Al acabar la fase de API:

```bash
terraform destroy -var 'allowed_ip=<tu IP pública>'
```

## Notas para el informe

- `vulnerable = 1` es el estado AS-IS. Con `-var 'vulnerable=0'` VAmPI activa sus controles: es parte de la demostración TO-BE.
- La base de datos vive dentro del contenedor: al escalar a cero se pierde y se reinicia con `GET /createdb`.
