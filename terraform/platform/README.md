# Raíz `platform`

Base común del laboratorio en Azure. Se despliega una vez, antes que las demás raíces, y queda fuera del alcance de explotación (solo revisión de configuración, ver `architecture/scope.md`).

| Recurso | Nombre | Para qué |
|---|---|---|
| Grupos de recursos | `rg-platform`, `rg-vampi` y `azuregoat_app` (swedencentral) | Separar la plataforma de las pilas vulnerables. `azuregoat_app` lo exige AzureGoat |
| Storage del estado | `tfstate<hash>` + contenedor `tfstate` | Estado remoto de todas las raíces. Sin claves compartidas: solo Entra ID |
| Rol de datos | Storage Blob Data Contributor sobre `tfstate` | Para quien ejecuta Terraform (el operador) |
| Presupuesto | `budget-cloud-security-lab` | Avisos al 50 % y 80 % del gasto real y al 100 % del previsto |

Además registra los proveedores de recursos de todas las pilas (Container Apps, Functions, Cosmos DB…), porque azurerm 5.x ya no lo hace solo.

**Sin despliegue desde GitHub.** Todas las raíces se aplican desde Azure Cloud Shell con la sesión del operador; GitHub no tiene ninguna credencial de Azure. La identidad OIDC prevista para desplegar desde GitHub Actions se descartó para priorizar el pentest.

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
terraform apply -var 'alert_email=tu@correo'
```

## Salida

`state_storage_account`: nombre del Storage del estado, que se pasa a `terraform init` en las demás raíces.

## Decisiones de seguridad

- **Estado sin claves:** `shared_access_key_enabled = false`, TLS 1.2, sin acceso anónimo, versionado y papelera de 7 días.
- **Endpoint público del Storage:** Cloud Shell no tiene IP fija. El acceso exige identidad y rol de datos. TO-BE: endpoint privado.
- **Sin credenciales de Azure en GitHub:** nada que robar desde el repositorio o un workflow. TO-BE, si el despliegue pasa a GitHub Actions: identidad con credencial federada OIDC, limitada a un environment de `main` con aprobación.
- **Presupuesto:** avisa, no corta el gasto. Los recursos facturables se destruyen al acabar.
- **Región:** West Europe no admitía altas nuevas para la suscripción; por eso `swedencentral` es la región por defecto.
