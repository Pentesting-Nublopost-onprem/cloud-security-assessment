# Raíz `platform`

Base común del laboratorio en Azure. Se despliega una vez, antes que las demás raíces, y queda fuera del alcance de explotación (solo revisión de configuración, ver `architecture/scope.md`).

| Recurso | Nombre | Para qué |
|---|---|---|
| Grupos de recursos | `rg-platform`, `rg-vampi`, `azuregoat_app` | Separar la plataforma de las pilas vulnerables. `azuregoat_app` lo exige AzureGoat |
| Storage del estado | `tfstate<hash>` + contenedor `tfstate` | Estado remoto de todas las raíces. Sin claves compartidas: solo Entra ID |
| Identidad de despliegue | `id-github-deploy` | GitHub Actions entra con OIDC, sin secretos guardados |
| Credencial federada | `github-azure-lab` | Solo acepta tokens de `Pentesting-Nublopost-onprem/cloud-security-assessment` con el environment `azure-lab` |
| Roles | ver abajo | Mínimos por grupo de recursos |
| Presupuesto | `budget-cloud-security-lab` | Avisos al 50 % y 80 % del gasto real y al 100 % del previsto |

Además registra los proveedores de recursos de todas las pilas (Container Apps, Functions, Cosmos DB…), porque azurerm 5.x ya no lo hace solo y la identidad de despliegue no tiene permisos de suscripción.

## Permisos de la identidad de despliegue

| Ámbito | Rol | Motivo |
|---|---|---|
| Contenedor `tfstate` | Storage Blob Data Contributor | Leer y escribir el estado |
| `rg-vampi` | Contributor | Desplegar VAmPI |
| `azuregoat_app` | Owner | AzureGoat crea asignaciones de roles. Riesgo aceptado y limitado a ese grupo |

## Primer despliegue (Azure Cloud Shell, Bash)

Cloud Shell ya trae Terraform y Azure CLI con la sesión iniciada, y no deja ficheros de estado en tu portátil ni en OneDrive.

```bash
az account show --query "{suscripcion:name, id:id}" -o table   # tu suscripción personal
git clone https://github.com/Pentesting-Nublopost-onprem/cloud-security-assessment.git
cd cloud-security-assessment/terraform/platform
./bootstrap.sh -var 'alert_email=tu@correo'
```

`bootstrap.sh` aplica con estado local, crea el Storage y migra el estado a él. Si tu suscripción no admite presupuestos, añade `-var 'create_budget=false'`.

## Usos posteriores

```bash
SA=$(az storage account list -g rg-platform --query "[0].name" -o tsv)
terraform init -backend-config="storage_account_name=$SA"
terraform plan
```

## Salidas

`state_storage_account`, `deploy_identity_client_id`, `tenant_id`, `subscription_id` y `github_oidc_subject`. Las tres del medio se guardan como variables (no secretos) del environment `azure-lab` en GitHub cuando se configuren los workflows de despliegue.

## Decisiones de seguridad

- **Estado sin claves:** `shared_access_key_enabled = false`, TLS 1.2, sin acceso anónimo, versionado y papelera de 7 días.
- **Endpoint público del Storage:** los runners de GitHub no tienen IP fija. El acceso exige identidad y rol de datos. TO-BE: endpoint privado con runner propio.
- **OIDC por environment:** el token solo sirve a jobs de este repositorio que usen el environment `azure-lab`, que se limitará a la rama `main` y con aprobación manual al configurar los workflows. Los pull requests desde forks no reciben token.
- **Presupuesto:** avisa, no corta el gasto. Los recursos facturables se destruyen al acabar cada sesión.
