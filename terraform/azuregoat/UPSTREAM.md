# Origen de AzureGoat y cambios

| Campo | Valor |
|---|---|
| Proyecto | [AzureGoat](https://github.com/ine-labs/AzureGoat) (INE) |
| Commit | `b97045952e6df00de735a7f27fd7c4994dcfe8c0` (30/10/2024, último del repositorio) |
| Licencia | MIT (ver `LICENSE`) |
| Incluido | `main.tf`, `modules/` y `LICENSE`. Los manuales de ataque y defensa y el PDF se quedan en el repositorio original |

**Vulnerable a propósito.** Solo se despliega en el laboratorio, en el grupo `azuregoat_app`, y se destruye al acabar la sesión de pruebas.

## Cambios para que se pueda desplegar hoy

Ninguno cambia el comportamiento de la aplicación ni las configuraciones inseguras que forman el laboratorio (contenedores públicos, SSRF, roles excesivos, SSH abierto, secretos en claro…).

| # | Cambio | Motivo |
|---|---|---|
| 1 | Región por defecto `swedencentral` (variable `location`), también para Cosmos DB, que tenía `eastus` fijo | La suscripción del laboratorio no puede crear recursos en las regiones más saturadas (West Europe lo rechazó el 14/11/2026) |
| 2 | IP pública de la VM `Standard` y `Static` | Azure retiró las IP públicas `Basic` el 30/09/2025 |
| 3 | Function Apps con runtime `~4`, Python 3.11, Node 22 y extension bundle `[4.*, 5.0.0)` | El runtime v3 en Linux Consumption dejó de ejecutarse el 30/09/2026; Python 3.9 y Node 12 ya no están soportados |
| 4 | Dependencias de la Function App (`.python_packages`) reconstruidas para Python 3.11, con las mismas versiones directas (PyJWT 1.7.1, azure-cosmos 4.3.0, azure-storage-blob 12.12.0, bcrypt 3.2.2) y `six` declarado | Las extensiones nativas originales eran para Python 3.9. Las dependencias transitivas suben de versión. Comprobado: el código de la función importa y funciona con estas librerías |
| 5 | VM con Ubuntu 22.04 LTS en lugar de 18.04 | La imagen de 18.04 ya no se puede desplegar |
| 6 | Estado remoto (`backend.tf`); `create-table.py` lee el endpoint y la clave de Cosmos DB de variables de entorno y ya no imprime la clave; `azure-cosmos==4.17.1` fijado para el seeding en lugar de una versión preliminar sin fijar | Con estado remoto no existe `terraform.tfstate` local, que era de donde el script sacaba las credenciales |
| 7 | `skip_provider_registration = true` en el proveedor | azurerm 3.11 intenta registrar 66 proveedores de recursos, entre ellos los de servicios ya retirados (Service Fabric Mesh, Data Lake Analytics, Media Services). Los que usa AzureGoat ya los registra la raíz `platform` |
| 8 | Clave de una cuenta de Storage de INE (`blogapidataprjstg`) en una línea comentada de `app/__init__.py`, sustituida por `REDACTED` | Es código muerto: la función usa la variable `CON_STR`. La protección de push de GitHub bloqueaba la subida. Esa cuenta no es del laboratorio y queda fuera del alcance |

**Finales de línea:** el original guarda muchos ficheros con CRLF (scripts, claves, JSON y la web compilada). El `.gitattributes` de este repositorio los normaliza a LF. No cambia el comportamiento: la extensión Custom Script de la VM ya convierte `config.sh` a LF antes de ejecutarlo y el resto se lee igual con cualquiera de los dos finales.

**Efecto en el catálogo de vulnerabilidades:** por los cambios 3 y 5 ya no hay componentes fuera de soporte en el sistema operativo ni en los runtimes. Siguen las librerías antiguas de la Function App (PyJWT 1.7.1) y el resto de fallos del laboratorio.
