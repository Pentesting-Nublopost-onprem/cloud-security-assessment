# Terraform en Azure: guía unificada

**Hecho por Cristian Rodríguez** · octubre de 2026

![Terraform 1.17](https://img.shields.io/badge/Terraform-1.17-7B42BC?logo=terraform&logoColor=white) ![azurerm 5.11](https://img.shields.io/badge/azurerm-5.11-0078D4?logo=microsoftazure&logoColor=white) ![azuread 3.10](https://img.shields.io/badge/azuread-3.10-0078D4?logo=microsoftazure&logoColor=white) ![Idioma: español](https://img.shields.io/badge/idioma-espa%C3%B1ol-555)

Sigue el orden de los 10 capítulos de *Terraform: Up & Running* (3.ª ed.) y, en cada uno, explica qué es cada recurso de Azure (AZ-104, SC-300, SC-500) y cómo se escribe en Terraform.

## Índice

| Capítulo | Qué aprendes de Terraform | Qué terraformizas en Azure |
| --- | --- | --- |
| [Cómo leer esta guía](#cómo-leer-esta-guía) | Fuentes, versiones y convenciones | Los cambios de azurerm 5.0 que rompen ejemplos antiguos |
| [1 · Por qué Terraform](#capítulo-1--por-qué-terraform) | IaC, cómo funciona Terraform, providers | Jerarquía de Azure: management groups, suscripciones, resource groups |
| [2 · Primeros pasos](#capítulo-2--primeros-pasos-con-terraform) | `resource`, variables, outputs, data sources | VNet, subred, NSG, VM, VM Scale Set, Load Balancer, autoescalado |
| [3 · El state](#capítulo-3--cómo-gestionar-el-state-de-terraform) | Backend remoto, bloqueo, aislamiento por carpetas | Storage Account segura, locks, Azure SQL |
| [4 · Módulos](#capítulo-4--infraestructura-reutilizable-con-módulos) | Entradas, locals, salidas, versionado | Azure Verified Modules, hub-and-spoke, peering, UDR, private endpoints |
| [5 · Bucles y condicionales](#capítulo-5--bucles-condicionales-despliegue-y-trampas) | `count`, `for_each`, `for`, `dynamic`, `import`, `moved` | Usuarios y grupos de Entra, RBAC, roles personalizados, unidades administrativas |
| [6 · Secretos](#capítulo-6--gestionar-secretos-con-terraform) | Recursos `ephemeral`, argumentos write-only, state seguro | Key Vault, managed identities, OIDC con GitHub |
| [7 · Varios providers](#capítulo-7--trabajar-con-varios-providers) | `alias`, `configuration_aliases`, `azapi` | Varias suscripciones, ACR, AKS |
| [8 · Código para producción](#capítulo-8--código-de-terraform-para-producción) | Módulos pequeños, validaciones, bloques `check` | Policy, locks, Defender for Cloud, logs, Backup, Conditional Access, PIM |
| [9 · Tests](#capítulo-9--cómo-testear-código-de-terraform) | `terraform test`, Terratest, análisis estático, policy as code | Suscripciones sandbox y limpieza de recursos de prueba |
| [10 · Terraform en equipo](#capítulo-10--terraform-en-equipo) | Flujo PR, plan y apply; importar lo que ya existe | Identidades del pipeline, GitHub Actions, Azure DevOps |
| [A · Equivalencias AWS → Azure](#apéndice-a--equivalencias-aws-libro--azure--terraform) | Leer el libro pensando en Azure | Tabla de recursos equivalentes |
| [B · Identidad (SC-300)](#apéndice-b--identidad-sc-300-en-terraform) | Qué se puede terraformizar en Entra ID | Invitaciones B2B, apps, licencias, entitlement management, access reviews, PIM for Groups |
| [C · Seguridad (SC-500)](#apéndice-c--seguridad-sc-500-en-terraform) | Qué se puede terraformizar en seguridad | Firewall, Bastion, Virtual Network Manager, WAF, Sentinel, Azure OpenAI |

---

## Cómo leer esta guía

Cada capítulo sigue los apartados del libro en su orden. Dentro de cada uno verás tres capas: la idea del libro (resumida con mis palabras y trasladada de AWS a Azure), qué es el recurso de Azure y para qué sirve, y cómo se escribe en Terraform. Bajo cada título, una línea en cursiva indica de qué guía sale el apartado; si no la hay, sale del libro.

### De dónde sale cada cosa

| Etiqueta | Fuente | Qué aporta |
| --- | --- | --- |
| **\[Libro\]** | *Terraform: Up & Running*, 3.ª ed. (Brikman, 2022) | Orden, conceptos y buenas prácticas de Terraform |
| **\[SC-500\]** | Mi *SC-500 Guía de Estudio Completa* (junio 2026) | Seguridad: Key Vault, Policy, RBAC, Storage, redes, Defender, Sentinel… |
| **\[SC-300\]** | Mi *SC-300 Guía de Estudio Completa* | Identidad: usuarios, grupos, apps, Conditional Access, PIM, gobernanza |
| **\[AZ-104\]** | Microsoft Learn (no tenía material propio) | Fundamentos: jerarquía, VNet, VM, VMSS, Load Balancer, Storage |
| **\[Docs\]** | Documentación oficial de los providers (repositorios de HashiCorp) | Nombres exactos de recursos y argumentos |

### Versiones usadas (a 26 de octubre de 2026)

El libro se escribió con Terraform 1.2 y el provider de AWS 4. Todo el código de esta guía está escrito para estas versiones y comprobado contra su documentación:

| Herramienta | Versión | Para qué |
| --- | --- | --- |
| Terraform CLI | 1.17.0 | Motor |
| `hashicorp/azurerm` | 5.11.0 | Recursos de Azure (Azure Resource Manager) |
| `hashicorp/azuread` | 3.10.0 | Objetos de Microsoft Entra ID (vía Microsoft Graph) |
| `azure/azapi` | 2.13.0 | Cualquier API de ARM que azurerm aún no cubra |
| `microsoft/msgraph` | 0.6.0 | Cualquier endpoint de Graph que azuread no cubra (aún 0.x) |
| OpenTofu | 1.13.2 | Fork open source de Terraform, compatible con casi todo lo de aquí |

### Si copias ejemplos antiguos de internet

azurerm 5.0 (27 de julio de 2026) rompió compatibilidad. Los errores que más verás al pegar código de blogs:

- El provider ya no registra *resource providers* por defecto. Decláralos con `resource_providers_to_register`.
- `azurerm_key_vault`: `enable_rbac_authorization` ya no existe; ahora `rbac_authorization_enabled` es obligatorio.
- `azurerm_storage_container`: usa `storage_account_id`, no `storage_account_name`.
- `azurerm_subnet`: `service_endpoints = [...]` pasa a bloques `service_endpoint { service = "..." }`.
- `azurerm_monitor_diagnostic_setting`: el bloque `metric` pasa a `enabled_metric`.
- `azurerm_network_watcher_flow_log`: `network_security_group_id` pasa a `target_resource_id`.
- `azurerm_federated_identity_credential`: `parent_id` pasa a `user_assigned_identity_id`.

### Convenciones

- Región `westeurope` y nombres con las abreviaturas del Cloud Adoption Framework: `rg-`, `vnet-`, `snet-`, `nsg-`, `pip-`, `lb-`, `vmss-`, `kv-`, `st`, `log-`.
- El libro usa AWS. La tabla completa de equivalencias está en el Apéndice A.
- Lo que no encaja en ningún capítulo del libro (identidad y seguridad avanzadas) está en los Apéndices B y C.

---

## Capítulo 1 — Por qué Terraform

Terraform describe en código declarativo cómo debe quedar tu infraestructura y llama a las APIs de Azure para que la realidad coincida con ese código. En Azure eso significa hablar con dos APIs distintas: Azure Resource Manager para los recursos y Microsoft Graph para Entra ID.

> [!NOTE]
> **Lo que vas a usar:** los providers `azurerm`, `azuread`, `azapi` y `msgraph`, y la jerarquía de Azure con `azurerm_management_group` y `azurerm_resource_group`.

### Qué es DevOps

El libro lo define como un conjunto de procesos, ideas y técnicas para que desarrollo y operaciones trabajen juntos. Sus cuatro pilares son cultura, automatización, medición y compartir. Terraform es la pieza de automatización de la infraestructura.

### Qué es Infrastructure as Code

IaC significa escribir código para definir, desplegar y actualizar infraestructura, en vez de hacerlo a mano en el portal. El libro distingue cinco familias de herramientas:

| Familia | Qué hace | Ejemplo en Azure |
| --- | --- | --- |
| Scripts ad hoc | Automatiza pasos sueltos | Un `.sh` con `az vm create` |
| Gestión de configuración | Instala y configura software en servidores ya existentes | Ansible, Azure Machine Configuration |
| Plantillas de servidor | Crea imágenes con todo instalado | Packer → Azure Compute Gallery |
| Orquestación | Despliega y gestiona contenedores o VMs a escala | AKS, VM Scale Sets |
| Aprovisionamiento | Crea la infraestructura en sí | Terraform, Bicep/ARM |

### Beneficios de IaC

Despliegues autoservicio, velocidad, documentación viva, control de versiones, validación con revisiones y tests, reutilización en módulos y menos trabajo repetitivo. En seguridad añade algo clave: cada cambio de RBAC, NSG o política queda en Git con autor, fecha y revisión. Eso es evidencia de control de cambios para ISO 27001.

### Cómo funciona Terraform en Azure

*Fuentes: Libro · AZ-104*

Terraform es un binario que lee tus ficheros `.tf`, calcula la diferencia con el estado actual y llama a los *providers*. Cada provider traduce recursos a llamadas API:

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/ch01-providers-dark.svg">
  <img src="img/ch01-providers-light.svg" alt="Cuatro providers, dos APIs: ARM para recursos y Microsoft Graph para Entra ID">
</picture>

`azurerm` y `azapi` hablan con ARM; `azuread` y `msgraph`, con Microsoft Graph. Por eso una configuración de Azure suele llevar dos providers desde el primer día (cap. 7).

**Azure Resource Manager (ARM)** es el plano de control de Azure. El portal, la CLI, PowerShell, Bicep y Terraform acaban todos llamando a la misma API REST de ARM. Por eso un permiso RBAC o una política `Deny` te afecta igual uses la herramienta que uses.

**Resource providers.** Cada servicio de Azure lo sirve un *resource provider* (`Microsoft.Compute`, `Microsoft.Network`, `Microsoft.KeyVault`…) que debe estar registrado en la suscripción. Desde azurerm 5.0 el provider no los registra por ti; declara los que uses o regístralos aparte.

### La jerarquía de Azure

*Fuente: AZ-104*

Todo lo que despliegues vive en cuatro niveles. RBAC y Azure Policy se heredan hacia abajo, así que el nivel donde asignas algo decide a qué afecta.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/ch01-jerarquia-dark.svg">
  <img src="img/ch01-jerarquia-light.svg" alt="Jerarquía de Azure: lo que asignas arriba se hereda en todo lo que cuelga debajo">
</picture>

Asigna roles y políticas en el nivel más alto que tenga sentido: una asignación en un management group llega a todas sus suscripciones, también a las que se añadan después.

| Nivel | Qué es | Límites y datos clave | Recurso Terraform |
| --- | --- | --- | --- |
| Tenant de Entra ID | Frontera de identidad; una suscripción confía en un único tenant | Un tenant puede tener muchas suscripciones | (no se crea con Terraform) |
| Management group | Contenedor de suscripciones para aplicar Policy y RBAC en bloque | 10.000 por directorio; hasta 6 niveles de profundidad sin contar la raíz | `azurerm_management_group` |
| Suscripción | Unidad de facturación, cuotas y frontera de acceso | Se suele usar una por entorno (dev, test, prod) | `azurerm_subscription` (alias), `azurerm_management_group_subscription_association` |
| Resource group | Contenedor lógico de recursos con el mismo ciclo de vida | Borrar el RG borra todo lo que contiene | `azurerm_resource_group` |
| Recurso | La instancia del servicio: VM, VNet, Key Vault… | Pertenece a un único RG | `azurerm_<tipo>` |

```hcl
resource "azurerm_management_group" "plataforma" {
  display_name = "Plataforma"
}

resource "azurerm_management_group" "corp" {
  display_name               = "Corp"
  parent_management_group_id = azurerm_management_group.plataforma.id
  subscription_ids           = [var.subscription_id_corp]
}
```

### Terraform frente a otras herramientas

El libro compara herramientas en varios ejes. Estos son los que importan al elegir en Azure:

| Eje | Terraform | ARM / Bicep |
| --- | --- | --- |
| Tipo | Aprovisionamiento, declarativo | Aprovisionamiento, declarativo |
| Estado | Fichero de estado propio (cap. 3) | Sin fichero: Azure es el estado; *deployment stacks* para gestionar borrados |
| Nubes | Multicloud y cientos de providers (GitHub, Datadog…) | Solo Azure |
| Entra ID | Provider `azuread` maduro | Extensión de Microsoft Graph para Bicep |
| Novedades de Azure | azurerm tarda algo; `azapi` cubre el día cero | Disponibles el día cero |
| Comunidad y módulos | Registry público y Azure Verified Modules | Azure Verified Modules también en Bicep |

Los otros ejes del libro se resumen rápido. **Mutable frente a inmutable:** Terraform sustituye recursos en lugar de parchearlos, como un VMSS que cambia de imagen. **Procedural frente a declarativo:** describes el estado final, no los pasos. **Sin master y sin agentes:** Terraform solo necesita credenciales para la API de Azure.

### Usar varias herramientas juntas

La combinación habitual en Azure es Terraform para la infraestructura, Packer o cloud-init (`custom_data`) para el software de las VMs, y AKS con Helm para los contenedores. Lo verás montado paso a paso en los capítulos 2 y 7.

---

## Capítulo 2 — Primeros pasos con Terraform

En AWS el libro despliega una instancia en la VPC por defecto. En Azure no hay red por defecto: para una sola VM necesitas resource group, VNet, subred, NIC y, si quieres acceso desde fuera, IP pública y NSG. El capítulo acaba con un VM Scale Set detrás de un load balancer.

> [!NOTE]
> **Lo que vas a usar:** `azurerm_virtual_network` · `azurerm_subnet` · `azurerm_network_security_group` · `azurerm_linux_virtual_machine` · `azurerm_linux_virtual_machine_scale_set` · `azurerm_lb` · `azurerm_monitor_autoscale_setting`

### Preparar tu cuenta de Azure

*Fuentes: Libro · SC-300 sesión 11*

El libro insiste en no trabajar con la cuenta raíz. En Azure, el equivalente es no usar una cuenta Global Administrator ni Owner para el día a día. Usa una suscripción de pruebas y un rol acotado:

| Necesidad | Rol de Azure RBAC |
| --- | --- |
| Crear y borrar recursos | Contributor en la suscripción o el resource group |
| Crear asignaciones de roles (cap. 5) | Role Based Access Control Administrator, idealmente con condiciones |
| Gestionar Entra ID (cap. 5 y Apéndice B) | Roles de Entra, no de Azure: User Administrator, Groups Administrator… |

Para trabajar en local, Terraform usa tu sesión de la Azure CLI:

```bash
az login
az account set --subscription "<id-de-tu-suscripcion>"
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

En pipelines no se usa tu usuario sino una **identidad de carga de trabajo** \[SC-300 sesión 11\]. Una *app registration* es la definición global de la aplicación; su *service principal* es la instancia en tu tenant, y es a él a quien das roles. Orden de preferencia: managed identity si el runner está en Azure, workload identity federation (OIDC, sin secretos) si está fuera, certificado si no queda otra y client secret como último recurso (máximo 2 años). Lo montamos en los capítulos 6 y 10.

### Instalar Terraform

```bash
# Windows
winget install Hashicorp.Terraform
# macOS
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
# Comprobar
terraform version
```

En Linux, instala desde el repositorio APT oficial de HashiCorp. Para tener varias versiones a la vez, usa `tfenv` (cap. 8).

### Desplegar un único servidor

*Fuentes: Libro · AZ-104*

Estos son los recursos mínimos y qué es cada uno:

| Recurso | Qué es \[AZ-104\] | Recurso Terraform |
| --- | --- | --- |
| Resource group | Contenedor con el ciclo de vida de la solución | `azurerm_resource_group` |
| Virtual network (VNet) | Red privada aislada, regional, con espacio de direcciones RFC 1918 | `azurerm_virtual_network` |
| Subred | Segmento de la VNet. Azure reserva 5 IP de cada subred (las 4 primeras y la última) | `azurerm_subnet` |
| NIC | La tarjeta de red de la VM; lleva la IP privada y, opcionalmente, una pública | `azurerm_network_interface` |
| Máquina virtual | Cómputo: tamaño (`Standard_B1s`), imagen y disco gestionado | `azurerm_linux_virtual_machine` |

Primero, el bloque `terraform` y el provider:

```hcl
terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.11"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id                = var.subscription_id
  resource_providers_to_register = ["Microsoft.Compute", "Microsoft.Network"]
}

# Pásala con: export TF_VAR_subscription_id=$(az account show --query id -o tsv)
variable "subscription_id" {
  description = "ID de la suscripción donde se despliega todo"
  type        = string
}
```

La sintaxis de cualquier recurso es `resource "<PROVIDER>_<TIPO>" "<NOMBRE>" { ... }`. El nombre solo existe dentro de Terraform. Para usar un atributo de otro recurso se escribe `<TIPO>.<NOMBRE>.<ATRIBUTO>`, y esa referencia crea una dependencia implícita: Terraform sabe que la subred va después de la VNet.

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-tfur-dev-weu"
  location = "westeurope"
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-tfur-dev"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                            = "snet-web"
  resource_group_name             = azurerm_resource_group.example.name
  virtual_network_name            = azurerm_virtual_network.example.name
  address_prefixes                = ["10.0.1.0/24"]
  default_outbound_access_enabled = false # subred privada
}
```

> [!IMPORTANT]
> **Subredes privadas por defecto.** Para las versiones de la API publicadas después del 31 de marzo de 2026, las VNets nuevas crean subredes privadas: las VMs ya no tienen salida implícita a Internet. Si una VM necesita salir (por ejemplo, para `apt install`), añade un método explícito: NAT Gateway (recomendado), reglas de salida del load balancer o una IP pública. Aquí lo dejamos explícito con `default_outbound_access_enabled = false`.

El flujo de trabajo básico:

```bash
terraform init     # descarga providers y crea .terraform.lock.hcl (súbelo a Git)
terraform plan     # + crear, ~ modificar, - destruir, -/+ sustituir
terraform apply
terraform graph -format=mermaid   # grafo de dependencias (Terraform 1.16+)
```

Añade al `.gitignore`: `.terraform/`, `*.tfstate`, `*.tfstate.backup` y cualquier `.tfvars` con secretos.

### Desplegar un servidor web

*Fuentes: Libro · SC-500 caps. 08 y 13*

El libro arranca un servidor HTTP con `user_data`. En Azure se usa `custom_data`, que procesa cloud-init en el primer arranque. Como la subred no tiene salida a Internet, el script usa el servidor HTTP de Python que ya trae Ubuntu, sin instalar nada:

```bash
#!/bin/bash
# user-data.sh
mkdir -p /var/www && cd /var/www
echo "Hola, mundo" > index.html
nohup python3 -m http.server ${server_port} &
```

Para que llegue tráfico necesitas un **Network Security Group** \[SC-500 cap. 08\]. Lo esencial:

- Es un filtro *stateful* de capa 3/4. Las reglas se evalúan por prioridad (100–4096, gana el número más bajo) y la primera coincidencia detiene la evaluación.
- Trae seis reglas por defecto en 65000–65500 que no se pueden borrar. En entrada: `AllowVNetInBound`, `AllowAzureLoadBalancerInBound` y `DenyAllInBound`. En salida: `AllowVnetOutBound`, `AllowInternetOutBound` y `DenyAllOutBound`. Se sobrescriben con reglas de prioridad más alta.
- La salida a Internet está permitida por defecto; solo la entrada es *deny by default*.
- Si hay NSG en la subred y en la NIC, el tráfico debe estar permitido por los dos. En entrada se evalúa primero el de subred y luego el de la NIC; en salida, al revés.

Y la VM usa **Trusted Launch** \[SC-500 cap. 13\]: Secure Boot impide cargar bootloaders o drivers sin firmar y el vTPM mide la cadena de arranque. No es lo mismo que Confidential VM, que además cifra la memoria frente al hipervisor.

```hcl
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  security_rule {
    name                       = "allow-http-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.server_port)
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "web" {
  name                = "pip-web-01"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard" # Basic ya no se puede crear
}

resource "azurerm_network_interface" "web" {
  name                = "nic-web-01"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-web-01"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_ed25519.pub") # ed25519 o RSA de 2048+ bits
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  secure_boot_enabled = true # Trusted Launch
  vtpm_enabled        = true

  custom_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
  }))
}
```

Dos detalles que en AWS se resuelven distinto. Cambiar `custom_data` **sustituye** la VM, que es justo lo que hace en el libro `user_data_replace_on_change`. Si quieres poder cambiarlo sin recrear la VM, usa el argumento `user_data`. Y las reglas pueden ir dentro del NSG (`security_rule`) o como `azurerm_network_security_rule` por separado, pero nunca mezcles los dos estilos (lo explica el cap. 4).

### Desplegar un servidor web configurable

Las variables evitan repetir valores y permiten cambiar la configuración sin tocar el código:

```hcl
variable "server_port" {
  description = "Puerto en el que el servidor atiende peticiones HTTP"
  type        = number
  default     = 8080

  validation {
    condition     = var.server_port > 1024 && var.server_port < 65536
    error_message = "Usa un puerto no privilegiado (1025-65535)."
  }
}

output "public_ip" {
  description = "IP pública del servidor web"
  value       = azurerm_public_ip.web.ip_address
}
```

| Concepto | Detalle |
| --- | --- |
| Tipos | `string`, `number`, `bool`, `list()`, `set()`, `map()`, `object({...})`, `tuple([...])`, `any` |
| Flags útiles | `sensitive` (oculta en la salida), `nullable`, `ephemeral` (1.10+, no se guarda en state ni plan), `deprecated` (1.15+) |
| Formas de dar valor, de menor a mayor prioridad | `default`, variables de entorno `TF_VAR_nombre`, `terraform.tfvars`, `*.auto.tfvars`, `-var-file`, `-var` |
| Outputs | `terraform output` o `terraform output -raw public_ip`. Desde la 1.15 admiten `type` explícito |

### Desplegar un clúster de servidores web

*Fuentes: Libro · AZ-104*

El Auto Scaling Group del libro equivale a un **Virtual Machine Scale Set (VMSS)** más una **regla de autoescalado** de Azure Monitor. Un VMSS tiene dos modos de orquestación, que se eligen al crearlo y no se pueden cambiar:

|  | Uniform | Flexible (recomendado por Microsoft) |
| --- | --- | --- |
| Instancias | VMs idénticas, gestionadas como grupo | VMs normales de Azure, se pueden mezclar tamaños y Spot |
| Salud | Sonda del load balancer o extensión Application Health | Solo extensión Application Health |
| Salida implícita a Internet (en subred no privada) | Sí | No, necesita salida explícita |
| Recurso Terraform | `azurerm_linux_virtual_machine_scale_set` | `azurerm_orchestrated_virtual_machine_scale_set` |

Aquí usamos Uniform porque la sonda del load balancer lo integra todo sin extensiones; es el equivalente más directo al ejemplo del libro. Para cargas nuevas en producción, valora Flexible.

```hcl
resource "azurerm_linux_virtual_machine_scale_set" "web" {
  name                = "vmss-web"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard_B1s"
  instances           = 2
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_ed25519.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  custom_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
  }))

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web.id]
    }
  }

  lifecycle {
    ignore_changes = [instances] # lo cambia el autoescalado
  }
}

resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "autoscale-vmss-web"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web.id

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    # Añade una segunda regla "Decrease" (p. ej. CPU < 25 %) para reducir
  }
}
```

El libro usa *data sources* para leer la VPC por defecto. En Azure se usan para leer cosas que ya existen y que no gestiona este código: `data "azurerm_client_config" "current" {}` (tu tenant y tu object ID) o `data "azurerm_subnet"` para una red creada por otro equipo.

### Desplegar un load balancer

*Fuentes: Libro · AZ-104*

El libro usa un Application Load Balancer (capa 7). En Azure hay cuatro opciones:

| Servicio | Capa | Ámbito | Cuándo |
| --- | --- | --- | --- |
| Azure Load Balancer (Standard) | 4 (TCP/UDP) | Regional | Repartir tráfico entre VMs o VMSS |
| Application Gateway | 7 (HTTP/S) + WAF | Regional | Rutas por URL, TLS, WAF regional |
| Azure Front Door | 7 + WAF | Global, en el edge | Apps globales, protección DDoS y bots en el borde |
| Traffic Manager | DNS | Global | Conmutar entre regiones por DNS |

Usamos Azure Load Balancer Standard; el SKU Basic está retirado. Se compone de cuatro piezas: IP de frontend, backend pool, sonda de salud y regla. El SKU Standard es seguro por defecto: no entra nada si el NSG no lo permite. Por eso el NSG de la subred permite el puerto 8080 desde `Internet`, mientras que las sondas entran por la regla por defecto `AllowAzureLoadBalancerInBound`.

```hcl
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-web"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "web" {
  name                = "lb-web"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "bepool-web"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "http" {
  name            = "probe-http"
  loadbalancer_id = azurerm_lb.web.id
  protocol        = "Http"
  port            = var.server_port
  request_path    = "/"
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-80"
  loadbalancer_id                = azurerm_lb.web.id
  frontend_ip_configuration_name = "public"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = var.server_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true # la salida, mejor con NAT Gateway
}

output "lb_public_ip" {
  value = azurerm_public_ip.lb.ip_address
}
```

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/ch02-arquitectura-dark.svg">
  <img src="img/ch02-arquitectura-light.svg" alt="Arquitectura del capítulo 2: load balancer Standard, VM Scale Set y autoescalado">
</picture>

El tráfico entra por la IP pública del load balancer, que solo lo envía a las instancias que responden a la sonda; el NSG de la subred filtra el puerto 8080 y el autoescalado ajusta el número de VMs.

### Limpieza

`terraform destroy` borra todo lo que gestiona la configuración; `terraform plan -destroy` te enseña antes qué borraría. Para recursos que nunca deben caer por error, añade `lifecycle { prevent_destroy = true }` y un *resource lock* de Azure (cap. 8). En una suscripción de pruebas, pon también un presupuesto con alertas (`azurerm_consumption_budget_subscription`).

---

## Capítulo 3 — Cómo gestionar el state de Terraform

El state es el fichero donde Terraform recuerda qué recurso real corresponde a cada bloque de tu código. En Azure se guarda en un blob de una Storage Account, que además bloquea el fichero con un *lease* mientras alguien hace `apply`: no necesitas nada equivalente a la tabla DynamoDB del libro.

> [!NOTE]
> **Lo que vas a usar:** el backend `azurerm` · `azurerm_storage_account` · `azurerm_storage_container` · `azurerm_management_lock` · `azurerm_mssql_server` · `terraform_remote_state`

### Qué es el state

`terraform.tfstate` es un JSON que asocia cada recurso, por ejemplo `azurerm_resource_group.example`, con su ID real en Azure (`/subscriptions/.../resourceGroups/rg-tfur-dev-weu`) y sus atributos. Reglas básicas:

- No se edita a mano. Para inspeccionarlo o moverlo: `terraform state list`, `state show`, `state mv`, `state rm`. Para refactorizar, mejor los bloques `moved`, `import` y `removed` (cap. 5).
- Guarda en claro todos los atributos, incluidas contraseñas y claves. Trátalo como un secreto (cap. 6).
- Nunca lo subas a Git.

### Almacenamiento compartido del state

*Fuentes: Libro · AZ-104 · SC-500 cap. 06*

En local, el state no sirve para trabajar en equipo: nadie más lo ve, no hay bloqueo y queda en tu disco sin cifrar. La solución es un *backend* remoto. En Azure es el backend `azurerm`, que guarda el state en un contenedor de blobs.

Una **Storage Account** \[AZ-104\] es el contenedor de los servicios de almacenamiento (blobs, ficheros, colas y tablas). Se usa el tipo StorageV2 y se elige redundancia:

| Redundancia | Copias | Protege frente a |
| --- | --- | --- |
| LRS | 3 en un mismo datacenter | Fallo de disco o rack |
| ZRS | 3 en zonas de disponibilidad distintas | Caída de una zona |
| GRS / GZRS | LRS o ZRS + copia asíncrona en la región emparejada | Caída de una región |
| RA-GRS / RA-GZRS | Igual, con lectura en la secundaria | Caída de región con lectura inmediata |

Mi guía del SC-500 lo resume en tres planos de seguridad independientes, y conviene aplicarlos al state porque contiene secretos:

| Plano \[SC-500 cap. 06\] | Opciones | Qué elegimos para el state |
| --- | --- | --- |
| Red | Firewall con redes seleccionadas, service endpoint, private endpoint | Firewall con la IP de tus runners o private endpoint |
| Autorización | Entra ID (RBAC), Shared Key, SAS, anónimo | Solo Entra ID: `shared_access_key_enabled = false` |
| Protección de datos | Soft delete de blobs y contenedores, versionado, inmutabilidad | Los tres primeros activados y un lock `CanNotDelete` |

> [!WARNING]
> **Dos trampas del examen con consecuencias reales**
>
> - **Plano de control y plano de datos.** Ser Owner o Contributor de la cuenta no da acceso a los blobs. Necesitas un rol de datos: Storage Blob Data Reader o Storage Blob Data Contributor.
> - **El lock solo protege el plano de control.** `CanNotDelete` impide borrar la cuenta, pero no borrar blobs. Para eso están el soft delete y el versionado.

El código que crea la cuenta del state vive en su propia carpeta (`global/tfstate`):

```hcl
provider "azurerm" {
  features {}
  subscription_id                = var.subscription_id
  storage_use_azuread            = true # la cuenta no admitirá claves compartidas
  resource_providers_to_register = ["Microsoft.Storage"]
}

variable "subscription_id" {
  type = string
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate-weu"
  location = "westeurope"
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "sttfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false # solo Entra ID
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true # cada escritura del state guarda una versión

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Rol de plano de datos: Contributor u Owner NO bastan para leer blobs
resource "azurerm_role_assignment" "tfstate_me" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_management_lock" "tfstate" {
  name       = "no-borrar-tfstate"
  scope      = azurerm_storage_account.tfstate.id
  lock_level = "CanNotDelete"
  notes      = "Contiene el state de Terraform"
}
```

La cuenta se cifra en reposo por defecto con claves de plataforma. Si te piden control de claves, añade una clave gestionada por el cliente (cap. 6). El cifrado de infraestructura (doble cifrado) solo se puede activar al crear la cuenta.

Con la cuenta creada, el libro hace el "truco del huevo y la gallina": primero `apply` con state local, luego añades el backend y migras.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-weu"
    storage_account_name = "sttfstatexxxxxx"
    container_name       = "tfstate"
    key                  = "global/tfstate/terraform.tfstate"
    use_azuread_auth     = true # Entra ID en vez de claves de acceso
  }
}
```

```bash
terraform init -migrate-state
```

A partir de aquí, cada `plan` o `apply` adquiere un *lease* sobre el blob. Si otra persona lanza un `apply` a la vez, Terraform espera o falla con un error de bloqueo. El versionado del blob te permite recuperar un state anterior si algo se corrompe.

### Limitaciones de los backends

El bloque `backend` sigue sin admitir variables ni locals, así que repetirías los mismos datos en cada módulo. La solución del libro es la configuración parcial: dejas en el código solo lo que cambia (`key`) y el resto va en un fichero común.

```hcl
# backend.hcl (común a todos los módulos de un entorno)
resource_group_name  = "rg-tfstate-weu"
storage_account_name = "sttfstatexxxxxx"
container_name       = "tfstate"
use_azuread_auth     = true
```

```bash
terraform init -backend-config=backend.hcl
```

> [!WARNING]
> **Un `key` distinto por módulo.** Si copias una carpeta y olvidas cambiarlo, dos módulos pisarán el mismo state. Terragrunt automatiza esto (cap. 8).

### Aislar el state

Un único state para todo significa que un error en dev puede romper prod. El libro propone dos formas de aislar.

**Aislamiento con workspaces.** `terraform workspace new stage` crea otro state con el mismo código y el mismo backend. En `azurerm`, el blob del workspace se llama `<key>env:<workspace>`, en el mismo contenedor. Puedes usar `terraform.workspace` para variar valores. Es cómodo para pruebas, pero débil para separar entornos: misma cuenta de state, mismas credenciales y nada visible en el código que diga en qué entorno estás.

**Aislamiento con estructura de carpetas** (la recomendación del libro). Cada entorno y cada componente es una carpeta con su propio backend. En Azure lo natural es alinear eso con una suscripción por entorno:

```text
live/
  global/
    tfstate/                 # la Storage Account del state
    identity/                # grupos de Entra y RBAC comunes
  stage/                     # suscripción de stage
    network/                 # VNet, subredes, NSG
    data-stores/sql/         # Azure SQL
    services/web-cluster/    # VMSS + load balancer
  prod/                      # suscripción de prod, con su propia cuenta de state
    network/
    data-stores/sql/
    services/web-cluster/
modules/                     # código reutilizable (cap. 4)
```

|  | Workspaces | Carpetas + suscripción por entorno |
| --- | --- | --- |
| Separación de credenciales | No | Sí, cada pipeline con su identidad |
| Radio de impacto de un error | Todo el backend | Un componente de un entorno |
| Se ve en qué entorno estás | No | Sí, por la ruta |
| Duplicación de código | Ninguna | Se evita con módulos (cap. 4) |

### El data source terraform\_remote\_state

*Fuentes: Libro · SC-500 cap. 07*

Con el state partido, un componente necesita datos de otro. El libro lee los outputs de la base de datos desde el clúster web con `terraform_remote_state`. Sirve en Azure, pero exige Storage Blob Data Reader sobre la cuenta y **lee el state entero**, secretos incluidos. Por eso, cuando el recurso se puede buscar, es mejor un data source del provider.

El ejemplo del libro usa MySQL en RDS. Aquí usamos **Azure SQL** con las recomendaciones de mi guía SC-500:

- **Solo autenticación Entra.** `azuread_authentication_only = true` desactiva los logins SQL, así que no hay contraseña que guardar. Los fallos de login Entra no aparecen en la auditoría de SQL sino en los sign-in logs de Entra.
- **RBAC no da acceso a datos.** SQL DB Contributor gestiona el recurso en ARM, pero no permite consultar. El acceso a datos se da dentro de la base de datos con `CREATE USER ... FROM EXTERNAL PROVIDER`.
- **Red.** Evita la casilla "Allow Azure services" (regla 0.0.0.0, abre a recursos de cualquier tenant). Usa private endpoint y desactiva el acceso público.
- **TDE** viene activado por defecto. Con clave propia (CMK), el Key Vault debe tener soft delete y purge protection.

```hcl
# stage/data-stores/sql/main.tf
resource "azurerm_resource_group" "data" {
  name     = "rg-data-stage-weu"
  location = "westeurope"
}

data "azuread_group" "sql_admins" {
  display_name     = "grp-sql-admins"
  security_enabled = true
}

resource "azurerm_mssql_server" "app" {
  name                          = "sql-tfur-stage-weu"
  resource_group_name           = azurerm_resource_group.data.name
  location                      = azurerm_resource_group.data.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false # acceso por private endpoint (cap. 4)

  azuread_administrator {
    login_username              = data.azuread_group.sql_admins.display_name
    object_id                   = data.azuread_group.sql_admins.object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "app" {
  name      = "sqldb-app"
  server_id = azurerm_mssql_server.app.id
  sku_name  = "S0"
}

output "sql_fqdn" {
  value = azurerm_mssql_server.app.fully_qualified_domain_name
}
```

Desde el clúster web, las dos formas de leer datos de otros componentes:

```hcl
# stage/services/web-cluster/main.tf
data "terraform_remote_state" "db" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-tfstate-weu"
    storage_account_name = "sttfstatexxxxxx"
    container_name       = "tfstate"
    key                  = "stage/data-stores/sql/terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Preferible cuando existe: buscar el recurso directamente
data "azurerm_subnet" "web" {
  name                 = "snet-web"
  virtual_network_name = "vnet-tfur-stage"
  resource_group_name  = "rg-network-stage-weu"
}
```

Y el valor leído se pasa al script de arranque con `templatefile`, igual que en el libro:

```hcl
custom_data = base64encode(templatefile("${path.module}/user-data.sh", {
  server_port = var.server_port
  db_fqdn     = data.terraform_remote_state.db.outputs.sql_fqdn
}))
```

---

## Capítulo 4 — Infraestructura reutilizable con módulos

Un módulo es cualquier carpeta con ficheros `.tf`. Sirve para escribir el clúster web una vez y desplegarlo en stage y en prod con parámetros distintos, en vez de copiar y pegar. En Azure también tienes módulos oficiales de Microsoft: los Azure Verified Modules.

> [!NOTE]
> **Lo que vas a usar:** bloques `module` · Azure Verified Modules · `azurerm_virtual_network_peering` · `azurerm_route_table` · `azurerm_private_endpoint` · `azurerm_private_dns_zone`

### Conceptos básicos

La carpeta donde ejecutas `terraform apply` es el *root module*. Los demás se llaman desde él con un bloque `module`. Mueve el código del capítulo 2 a una carpeta propia:

```text
modules/
  services/
    webserver-cluster/
      main.tf
      variables.tf
      outputs.tf
      user-data.sh
live/
  stage/services/web-cluster/main.tf   # llama al módulo
  prod/services/web-cluster/main.tf    # lo llama con otros valores
```

Un módulo reutilizable **no debe llevar bloque `provider`**: lo hereda de quien lo llama (cap. 7). Cada vez que añades un módulo o cambias su `source`, hay que repetir `terraform init`.

### Entradas del módulo

Lo que en el capítulo 2 estaba fijo pasa a ser variable:

```hcl
# modules/services/webserver-cluster/variables.tf
variable "cluster_name" {
  description = "Nombre base de todos los recursos del clúster"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  description = "Subred donde viven las instancias"
  type        = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "server_port" {
  type    = number
  default = 8080
}

variable "ssh_public_key" {
  type = string
}

variable "custom_tags" {
  type    = map(string)
  default = {}
}
```

### Locals del módulo

Los *locals* son valores con nombre que solo existen dentro del módulo. Evitan repetir literales sin exponerlos como variables:

```hcl
locals {
  http_port = 80
  tags      = merge({ cluster = var.cluster_name, managed_by = "terraform" }, var.custom_tags)
}
```

### Salidas del módulo

Un módulo solo expone lo que declara como output. Desde fuera se lee como `module.<NOMBRE>.<OUTPUT>`.

```hcl
# modules/services/webserver-cluster/outputs.tf
output "lb_public_ip" {
  description = "IP pública del load balancer"
  value       = azurerm_public_ip.lb.ip_address
}

output "vmss_id" {
  value = azurerm_linux_virtual_machine_scale_set.this.id
}

output "nsg_name" {
  description = "Para que quien llama pueda añadir reglas"
  value       = azurerm_network_security_group.this.name
}
```

El `main.tf` del módulo es el código del capítulo 2 con los valores fijos cambiados por `var.*` y `local.*`, y los nombres construidos con `"vmss-${var.cluster_name}"`, `"lb-${var.cluster_name}"`, etc. Lo interesante está en las dos trampas del siguiente apartado.

Así se usa desde stage. En prod solo cambian los valores: `cluster_name = "web-prod"`, `vm_size = "Standard_B2s"` y `max_size = 10`.

```hcl
# live/stage/services/web-cluster/main.tf
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name        = "web-stage"
  resource_group_name = azurerm_resource_group.web.name
  location            = azurerm_resource_group.web.location
  subnet_id           = data.azurerm_subnet.web.id
  vm_size             = "Standard_B1s"
  min_size            = 2
  max_size            = 2
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")
}

output "lb_public_ip" {
  value = module.webserver_cluster.lb_public_ip
}
```

### Trampas de los módulos

**Rutas de ficheros.** `file()` y `templatefile()` resuelven rutas desde donde ejecutas Terraform, no desde el módulo. Usa `path.module` dentro de módulos (`path.root` es el root module y `path.cwd` el directorio actual):

```hcl
custom_data = base64encode(templatefile("${path.module}/user-data.sh", {
  server_port = var.server_port
}))
```

**Bloques inline.** Muchos recursos de Azure permiten definir hijos de dos formas, dentro del padre o como recurso aparte. Si las mezclas, Terraform y Azure se pelean y ves diferencias en cada `plan`.

| Padre con bloque inline | Recurso separado equivalente |
| --- | --- |
| `azurerm_network_security_group` → `security_rule` | `azurerm_network_security_rule` |
| `azurerm_virtual_network` → `subnet` | `azurerm_subnet` |
| `azurerm_route_table` → `route` | `azurerm_route` |

En un módulo, usa recursos separados: así quien lo llama puede añadir reglas sin tocarlo. Dentro del módulo:

```hcl
resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.cluster_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_network_security_rule" "allow_app" {
  name                        = "allow-app-inbound"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.server_port)
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
}
```

Y en stage, una regla extra solo para pruebas:

```hcl
resource "azurerm_network_security_rule" "allow_testing" {
  name                        = "allow-testing-12345"
  resource_group_name         = azurerm_resource_group.web.name
  network_security_group_name = module.webserver_cluster.nsg_name
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "12345"
  source_address_prefix       = "203.0.113.10"
  destination_address_prefix  = "*"
}
```

### Versionado de módulos

Si stage y prod apuntan a la misma carpeta, cualquier cambio llega a los dos a la vez. La solución es poner los módulos en su propio repositorio, etiquetar versiones con *semantic versioning* y fijar la versión en cada entorno:

```hcl
module "webserver_cluster" {
  # GitHub
  source = "git::https://github.com/cristianrdgzzz/terraform-azure-modules.git//services/webserver-cluster?ref=v0.3.0"

  # Azure Repos (alternativa)
  # source = "git::https://dev.azure.com/<org>/<proyecto>/_git/terraform-modules//services/webserver-cluster?ref=v0.3.0"

  # ...mismas entradas...
}
```

Stage puede probar `v0.4.0` mientras prod sigue en `v0.3.0`. Desde Terraform 1.15, `source` y `version` admiten variables y locals, así que puedes centralizar las versiones en un sitio.

**Azure Verified Modules (AVM).** Son módulos oficiales de Microsoft en el registry público, con nombres `Azure/avm-res-<servicio>-<recurso>/azurerm`. Muchos están escritos con el provider `azapi`, por eso piden `parent_id` (el ID del resource group) en vez de `resource_group_name`:

```hcl
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.3"

  name          = "vnet-app-stage"
  location      = "westeurope"
  parent_id     = azurerm_resource_group.network.id
  address_space = ["10.1.0.0/16"]

  subnets = {
    web = {
      name           = "snet-web"
      address_prefix = "10.1.1.0/24"
    }
    pe = {
      name           = "snet-pe"
      address_prefix = "10.1.2.0/24"
    }
  }
}
```

Regla práctica: usa AVM para piezas estándar y escribe módulos propios cuando necesites encapsular las decisiones de tu empresa (nombres, tags, políticas de seguridad).

### Otro módulo típico: la red spoke

*Fuentes: AZ-104 · SC-500 cap. 09*

Casi todas las empresas en Azure usan topología *hub-and-spoke*: una VNet hub con los servicios compartidos (firewall, DNS, VPN) y una VNet spoke por aplicación o entorno. Es un candidato perfecto a módulo. Los conceptos que encapsula:

| Concepto | Lo esencial |
| --- | --- |
| VNet peering \[AZ-104\] | Conecta dos VNets por el backbone de Microsoft. Hay que crearlo en los dos sentidos, no es transitivo y los espacios de direcciones no pueden solaparse |
| Ruta definida por usuario, UDR \[AZ-104\] | Sobrescribe las rutas de sistema. Con `0.0.0.0/0` y next hop `VirtualAppliance` hacia la IP del Azure Firewall, todo lo que sale pasa por él |
| Private endpoint \[SC-500 cap. 09\] | NIC con IP privada de tu VNet que apunta a una instancia concreta de un PaaS. Es el único modelo con protección contra exfiltración y accesible desde on-premises |
| Service endpoint \[SC-500 cap. 09\] | La subred se identifica ante el PaaS, pero el servicio sigue teniendo IP pública y aplica a todas sus instancias. Gratis y sin DNS |
| Zona DNS privada | `privatelink.database.windows.net`, `privatelink.vaultcore.azure.net`… Si no está bien enlazada, el FQDN resuelve a la IP pública y el tráfico sale por Internet sin que nada avise |

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/ch04-hub-spoke-dark.svg">
  <img src="img/ch04-hub-spoke-light.svg" alt="Topología hub-and-spoke: la salida de cada spoke pasa por el firewall del hub">
</picture>

El módulo spoke crea la VNet, sus subredes, la UDR y el peering en los dos lados; el hub vive en la suscripción de conectividad (cap. 7).

> [!WARNING]
> **Tres avisos de mi guía.** Crear el private endpoint **no cierra la puerta pública**: desactiva el acceso público en el PaaS aparte. Cada subrecurso (blob, file, sqlServer…) necesita su propio endpoint y su zona. Y si quieres que los NSG y UDR apliquen a los private endpoints, activa las *network policies* en su subred.

```hcl
# modules/networking/spoke/main.tf (variables y outputs abreviados)
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
}

resource "azurerm_subnet" "web" {
  name                            = "snet-web"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [var.web_subnet_prefix]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "pe" {
  name                              = "snet-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.pe_subnet_prefix]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled" # NSG y UDR también aplican a los PE
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.name}-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = var.hub_vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.name}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.this.id
  allow_forwarded_traffic   = true
}

resource "azurerm_route_table" "this" {
  name                          = "rt-${var.name}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "web" {
  subnet_id      = azurerm_subnet.web.id
  route_table_id = azurerm_route_table.this.id
}

# Enlaza las zonas privatelink.* del hub con esta VNet (for_each: cap. 5)
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.private_dns_zone_ids # mapa nombre de zona => ID

  name                = "link-${var.name}-${each.key}"
  private_dns_zone_id = each.value
  virtual_network_id  = azurerm_virtual_network.this.id
}
```

Y el private endpoint del Azure SQL del capítulo 3, con su zona privada:

```hcl
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-tfur-stage"
  resource_group_name = azurerm_resource_group.data.name
  location            = azurerm_resource_group.data.location
  subnet_id           = module.spoke.pe_subnet_id # output del módulo spoke de este entorno

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.app.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  # Crea el registro A en la zona privada
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
```

Con decenas de VNets, el peering uno a uno no escala. Azure Virtual Network Manager crea topologías *mesh* o *hub-and-spoke* y reglas de seguridad centrales (Apéndice C).

---

## Capítulo 5 — Bucles, condicionales, despliegue y trampas

Este es el capítulo donde Terraform deja de ser "un recurso, un bloque". Los ejemplos del libro crean usuarios IAM en bucle; aquí creamos usuarios y grupos de Entra ID, membresías y asignaciones de RBAC, que es justo lo que más vas a terraformizar en identidad.

> [!NOTE]
> **Lo que vas a usar:** `azuread_user` · `azuread_group` · `azuread_group_member` · `azurerm_role_assignment` · `azurerm_role_definition` · `azuread_administrative_unit` · bloques `import`, `moved` y `removed`

### Bucles con count

*Fuentes: Libro · SC-300 sesión 02*

`count` crea N copias de un recurso; dentro, `count.index` vale 0, 1, 2… Para Entra, `azuread_user` exige UPN con un dominio verificado del tenant y una contraseña inicial:

```hcl
variable "user_names" {
  type    = list(string)
  default = ["neo", "trinity", "morpheus"]
}

resource "random_password" "count_example" {
  count   = length(var.user_names)
  length  = 24
  special = true
}

resource "azuread_user" "count_example" {
  count = length(var.user_names)

  user_principal_name   = "${var.user_names[count.index]}@${var.domain}"
  display_name          = title(var.user_names[count.index])
  password              = random_password.count_example[count.index].result
  force_password_change = true
}
```

> [!WARNING]
> **El problema que explica el libro:** los recursos se identifican por posición. Si quitas `"trinity"` de la lista, `morpheus` pasa del índice 2 al 1 y Terraform quiere **borrar y recrear** usuarios que no has tocado. En Entra eso significa object IDs nuevos y pérdida de grupos, licencias y roles.

### Bucles con for\_each

*Fuentes: Libro · SC-300 sesiones 01 y 02 · SC-500 cap. 04*

`for_each` recorre un *set* o un *map* e identifica cada copia por su clave (`each.key`, `each.value`). Quitar un elemento solo borra ese elemento:

```hcl
variable "users" {
  type = map(object({
    display_name = string
    department   = string
  }))
  default = {
    neo      = { display_name = "Neo", department = "IT" }
    trinity  = { display_name = "Trinity", department = "Security" }
    morpheus = { display_name = "Morpheus", department = "Security" }
  }
}

resource "random_password" "initial" {
  for_each = var.users
  length   = 24
  special  = true
}

resource "azuread_user" "this" {
  for_each = var.users

  user_principal_name   = "${each.key}@${var.domain}"
  display_name          = each.value.display_name
  department            = each.value.department
  usage_location        = "ES" # obligatorio para asignar licencias
  password              = random_password.initial[each.key].result
  force_password_change = true
}
```

Las contraseñas iniciales quedan en el state (cap. 6). En empresas con identidad híbrida los usuarios no se crean con Terraform: llegan desde Active Directory con Entra Connect o Cloud Sync, y sus atributos se editan en on-premises \[SC-300 sesión 04\].

**Grupos y membresías.** Recuerda de mi guía: los grupos de **seguridad** admiten usuarios, dispositivos, service principals y otros grupos de seguridad; los de **Microsoft 365** solo usuarios y no se anidan. La membresía es *Assigned* o *Dynamic*. Para cruzar grupos y usuarios hace falta aplanar una lista de pares:

```hcl
variable "groups" {
  type = map(object({
    description = string
    members     = list(string)
  }))
  default = {
    "grp-security-team" = { description = "Equipo de seguridad", members = ["trinity", "morpheus"] }
    "grp-it-ops"        = { description = "Operaciones de IT", members = ["neo"] }
  }
}

resource "azuread_group" "this" {
  for_each = var.groups

  display_name     = each.key
  description      = each.value.description
  security_enabled = true
}

locals {
  memberships = {
    for pair in flatten([
      for group, cfg in var.groups : [
        for user in cfg.members : { group = group, user = user }
      ]
    ]) : "${pair.group}/${pair.user}" => pair
  }
}

resource "azuread_group_member" "this" {
  for_each = local.memberships

  group_object_id  = azuread_group.this[each.value.group].object_id
  member_object_id = azuread_user.this[each.value.user].object_id
}
```

> [!WARNING]
> **Trampa:** no mezcles `azuread_group_member` con el argumento `members` del grupo: se borran mutuamente los miembros (es la trampa de los bloques inline del cap. 4).

**Grupos dinámicos** \[SC-300 sesión 02\]. La regla se evalúa continuamente contra los atributos del directorio. Requieren Entra ID P1 para cada usuario del grupo, son de usuarios o de dispositivos (nunca ambos) y hay un máximo de 15.000 por tenant. Si conviertes un grupo estático en dinámico, los que no cumplan la regla salen al instante.

```hcl
resource "azuread_group" "security_dynamic" {
  display_name     = "grp-dyn-dept-security"
  security_enabled = true
  types            = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = "user.department -eq \"Security\""
  }
}
```

**Asignaciones de RBAC en bucle** \[SC-500 cap. 04\]. Una asignación une tres cosas: un principal (usuario, grupo, service principal o managed identity), una definición de rol y un ámbito. Las asignaciones son aditivas (recibes la unión de todas) y se heredan hacia abajo sin posibilidad de bloquearlas. Asigna siempre a grupos, no a personas:

```hcl
locals {
  rbac = {
    secops_reader = {
      group = "grp-security-team"
      role  = "Security Reader"
      scope = "/subscriptions/${var.subscription_id}"
    }
    itops_vm = {
      group = "grp-it-ops"
      role  = "Virtual Machine Contributor"
      scope = azurerm_resource_group.web.id
    }
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = local.rbac

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azuread_group.this[each.value.group].object_id
  principal_type       = "Group"
}
```

Los cuatro roles base que mi guía pide saber de memoria:

| Rol | Lee | Escribe/borra | Gestiona accesos |
| --- | --- | --- | --- |
| Owner | Sí | Sí | Sí |
| Contributor | Sí | Sí | No |
| Reader | Sí | No | No |
| User Access Administrator | Limitado | No | Sí |

Y roles de servicio que aparecen una y otra vez: Key Vault Secrets User (lee secretos), Key Vault Reader (solo metadatos, **no** valores), Storage Blob Data Reader/Contributor (datos, no gestión), Security Reader y Security Admin (Defender for Cloud).

**Roles personalizados.** Cuando ningún rol integrado cumple el mínimo privilegio. Este es el ejemplo JSON de mi guía, en Terraform:

```hcl
resource "azurerm_role_definition" "vm_restart_operator" {
  name        = "VM Restart Operator"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Puede ver y reiniciar VMs; no puede borrarlas ni leer secretos"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/restart/action",
    ]
    not_actions = []
  }

  assignable_scopes = ["/subscriptions/${var.subscription_id}"]
}

resource "azurerm_role_assignment" "restart_ops" {
  scope              = azurerm_resource_group.web.id
  role_definition_id = azurerm_role_definition.vm_restart_operator.role_definition_resource_id
  principal_id       = azuread_group.this["grp-it-ops"].object_id
  principal_type     = "Group"
}
```

> [!WARNING]
> **Dos trampas.** `not_actions` resta dentro del mismo rol, pero **no es un deny** frente a otra asignación. Y las *deny assignments* no las puedes crear tú: las crean servicios de Azure como los managed applications. Para impedir borrados incluso a un Owner, usa un resource lock (cap. 8).

**Roles de Entra y unidades administrativas** \[SC-300 sesión 01\]. No confundas los dos sistemas de roles:

|  | Azure RBAC | Roles de Entra ID |
| --- | --- | --- |
| Controla | Recursos de Azure (VMs, Key Vault…) | Objetos del directorio (usuarios, grupos, apps) |
| Ámbito | Management group, suscripción, RG, recurso | Tenant (`/`), unidad administrativa o un objeto |
| Ejemplos | Owner, Contributor, Reader | Global Administrator, User Administrator, Helpdesk Administrator |
| Recurso Terraform | `azurerm_role_assignment` | `azuread_directory_role_assignment` |

Una unidad administrativa (AU) limita dónde aplica un rol de Entra. Lo que mi guía marca como trampas: las AU no se anidan, añadir un grupo a una AU no añade a sus miembros, y la AU limita permisos de gestión pero no la lectura por defecto del directorio.

```hcl
resource "azuread_administrative_unit" "madrid" {
  display_name = "AU-Madrid"
}

resource "azuread_administrative_unit_member" "neo" {
  administrative_unit_object_id = azuread_administrative_unit.madrid.object_id
  member_object_id              = azuread_user.this["neo"].object_id
}

resource "azuread_directory_role" "helpdesk" {
  display_name = "Helpdesk Administrator" # activa el rol integrado en el tenant
}

resource "azuread_directory_role_assignment" "helpdesk_madrid" {
  role_id             = azuread_directory_role.helpdesk.template_id
  principal_object_id = azuread_user.this["trinity"].object_id
  directory_scope_id  = "/administrativeUnits/${azuread_administrative_unit.madrid.object_id}"
}
```

Para roles privilegiados, la asignación permanente que acabas de ver no es la buena práctica: lo correcto es una asignación *eligible* en PIM (cap. 8).

**Bloques dinámicos.** `dynamic` genera bloques anidados en bucle. Sirve para reglas de NSG declaradas como datos:

```hcl
variable "nsg_rules" {
  type = map(object({
    priority = number
    port     = string
    source   = string
  }))
  default = {
    http  = { priority = 100, port = "80", source = "Internet" }
    https = { priority = 110, port = "443", source = "Internet" }
  }
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  dynamic "security_rule" {
    for_each = var.nsg_rules

    content {
      name                       = "allow-${security_rule.key}"
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefix      = security_rule.value.source
      destination_address_prefix = "*"
    }
  }
}
```

También puedes poner `for_each` en un bloque `module` para desplegar el mismo módulo varias veces.

### Bucles con expresiones for

Una expresión `for` transforma listas y mapas. Es lo que usas para construir outputs o mapas de búsqueda:

```hcl
output "user_upns" {
  value = [for u in azuread_user.this : u.user_principal_name]
}

output "group_ids" {
  value = { for name, g in azuread_group.this : name => g.object_id }
}
```

Un uso muy de Azure: calcular subredes con `cidrsubnet` en vez de escribirlas a mano.

```hcl
locals {
  vnet_cidr = "10.10.0.0/16"
  subnets = {
    web = cidrsubnet(local.vnet_cidr, 8, 1) # 10.10.1.0/24
    app = cidrsubnet(local.vnet_cidr, 8, 2) # 10.10.2.0/24
    pe  = cidrsubnet(local.vnet_cidr, 8, 3) # 10.10.3.0/24
  }
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                            = "snet-${each.key}"
  resource_group_name             = azurerm_resource_group.example.name
  virtual_network_name            = azurerm_virtual_network.example.name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = false
}
```

Prueba funciones sin desplegar nada con `terraform console`.

### Bucles con la directiva de cadena for

Dentro de un texto, `%{ for }` repite fragmentos. El `~` elimina los saltos de línea sobrantes:

```hcl
output "resumen" {
  value = <<-EOT
  %{for name, u in azuread_user.this~}
  ${name}: ${u.user_principal_name}
  %{endfor~}
  EOT
}
```

### Condicionales

Terraform no tiene `if`. El libro enseña tres trucos.

**Con count:** `count = condición ? 1 : 0` crea o no un recurso. Para leerlo luego, usa `one()`:

```hcl
variable "enable_autoscaling" {
  type    = bool
  default = true
}

resource "azurerm_monitor_autoscale_setting" "this" {
  count = var.enable_autoscaling ? 1 : 0
  # ...
}

output "autoscale_id" {
  value = one(azurerm_monitor_autoscale_setting.this[*].id)
}
```

**If-else con el operador ternario.** A menudo basta con elegir un valor:

```hcl
resource "azurerm_role_assignment" "neo" {
  scope                = azurerm_resource_group.web.id
  role_definition_name = var.give_neo_contributor ? "Contributor" : "Reader"
  principal_id         = azuread_user.this["neo"].object_id
  principal_type       = "User"
}
```

**Con for\_each y for:** filtra con `if` dentro de la expresión, por ejemplo `{ for k, v in var.users : k => v if v.department == "Security" }`. **Con la directiva de cadena:** `%{ if condición }...%{ else }...%{ endif }`.

### Despliegue sin caída

*Fuentes: Libro · AZ-104*

El libro consigue *zero-downtime* con `create_before_destroy` y, después, con el *instance refresh* del ASG. En un VMSS el equivalente es la **actualización gradual** (*rolling upgrade*): al cambiar la imagen o el `custom_data`, Azure sustituye las instancias por lotes y solo sigue si la sonda de salud da el visto bueno.

```hcl
resource "azurerm_linux_virtual_machine_scale_set" "this" {
  # ...lo mismo que en el módulo del cap. 4...

  upgrade_mode    = "Rolling" # cambiarlo después obliga a recrear el VMSS
  health_probe_id = azurerm_lb_probe.http.id

  rolling_upgrade_policy {
    max_batch_instance_percent              = 50
    max_unhealthy_instance_percent          = 50
    max_unhealthy_upgraded_instance_percent = 20
    pause_time_between_batches              = "PT30S"
    maximum_surge_instances_enabled         = true # crea las nuevas antes de borrar las viejas
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }

  custom_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    server_text = var.server_text # cámbialo y verás el rolling upgrade
  }))

  depends_on = [azurerm_lb_rule.http] # la sonda debe estar en uso por una regla
}
```

Para aplicaciones web, App Service lo resuelve con *deployment slots* y un *swap*. Y si quieres un azul-verde de verdad, crea un segundo VMSS con `create_before_destroy` y cambia el backend pool.

### Trampas de Terraform

**count y for\_each tienen límites.** Sus valores deben conocerse en el `plan`. Si dependen de algo que solo existe tras el `apply` (un ID generado), verás *Invalid count/for\_each argument*. Usa claves que tú controles (nombres) y no IDs. Las *deferred actions* (`terraform plan -allow-deferral`) lo relajarán, pero por ahora son un experimento que solo existe en las versiones alpha de Terraform.

**El despliegue sin caída tiene límites.** Con autoescalado, el número de instancias lo cambia Azure: por eso el `ignore_changes = [instances]` del cap. 2. Y algunos argumentos del VMSS (`upgrade_mode`, `rolling_upgrade_policy`) obligan a recrearlo entero.

**Los planes válidos pueden fallar.** `plan` solo compara tu código con el state, no con Azure. En Azure falla típicamente por:

- Un recurso que ya existe fuera de Terraform. azurerm se niega a pisarlo y te pide importarlo.
- Nombres globales: Storage Accounts y Key Vaults son únicos en todo Azure, y un Key Vault borrado en soft delete sigue reservando su nombre.
- Una política `Deny` de Azure Policy (cap. 8). azurerm 5.x puede llamar a la API de *preflight* durante el `plan` (`features { enhanced_validation { preflight_enabled = true } }`), pero solo para algunos recursos.

Para traer recursos existentes, usa un bloque `import` (Terraform 1.5+). `terraform plan -generate-config-out=generated.tf` te escribe el código de partida:

```hcl
import {
  to = azurerm_resource_group.legacy
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-creado-a-mano"
}
```

**La consistencia eventual de Entra.** Si creas un service principal y en el mismo `apply` le asignas un rol, la asignación puede fallar con *PrincipalNotFound* porque Entra aún no ha replicado el objeto:

```hcl
resource "azurerm_role_assignment" "new_sp" {
  scope                            = azurerm_key_vault.app.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azuread_service_principal.app.object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
```

**Refactorizar es delicado.** Cambiar el nombre de un recurso en el código es, para Terraform, borrar uno y crear otro. Antes de cada `apply`, busca en el plan la frase *forces replacement*. Las herramientas modernas:

```hcl
# Pasar de count a for_each sin recrear usuarios (Terraform 1.1+)
moved {
  from = azuread_user.count_example[0]
  to   = azuread_user.this["neo"]
}

# Dejar de gestionar algo sin destruirlo (Terraform 1.7+)
removed {
  from = azurerm_resource_group.legacy

  lifecycle {
    destroy = false
  }
}
```

---

## Capítulo 6 — Gestionar secretos con Terraform

La mejor estrategia en Azure es no tener secretos: identidades administradas para los recursos, OIDC para los pipelines y autenticación Entra para bases de datos y storage. Para lo que quede, Key Vault y los argumentos *write-only* de Terraform 1.11+, que no dejan el valor en el state.

> [!NOTE]
> **Lo que vas a usar:** `azurerm_key_vault` · `azurerm_key_vault_key` · `azurerm_key_vault_secret` · `azurerm_user_assigned_identity` · `azurerm_federated_identity_credential` · recursos `ephemeral` y argumentos `_wo`

### Fundamentos de la gestión de secretos

Dos reglas: nunca guardes secretos en texto plano y nunca en Git. El libro distingue tres tipos:

| Tipo | Ejemplo en Azure | Dónde va |
| --- | --- | --- |
| Personales | Tu contraseña del portal, tu clave SSH | Gestor de contraseñas personal |
| De clientes | Contraseñas o datos de usuarios de tu app | Hash con bcrypt/Argon2 en la base de datos |
| De infraestructura | Contraseña de SQL, claves de API, certificados TLS | Key Vault (o, mejor, eliminarlos con identidades) |

### Herramientas de gestión de secretos

| Herramienta | Almacén | Cuándo |
| --- | --- | --- |
| Azure Key Vault (Standard/Premium) | Centralizado, gestionado | Por defecto en Azure |
| Azure Managed HSM | HSM dedicado de un solo tenant, FIPS 140-3 nivel 3 | Requisitos regulatorios fuertes (PCI-DSS, banca) |
| HashiCorp Vault / OpenBao | Centralizado, autogestionado | Multicloud, secretos dinámicos |
| sops + clave de Key Vault | Ficheros cifrados en Git | Cuando el secreto debe vivir junto al código |

### Azure Key Vault a fondo

*Fuente: SC-500 cap. 02*

Key Vault guarda tres tipos de objeto: **secretos** (cualquier valor opaco: contraseñas, cadenas de conexión), **claves** (RSA o EC, para cifrar con clave propia Storage, SQL o discos) y **certificados** (X.509 con su clave privada). Las decisiones que mi guía marca como clave:

| Decisión | Opción recomendada | Por qué |
| --- | --- | --- |
| Modelo de acceso | Azure RBAC | Granularidad hasta un secreto concreto, PIM y Conditional Access. Las access policies son *legacy*: solo a nivel de vault y sin PIM |
| Tier | Standard; Premium si las claves deben estar en HSM | El HSM de Premium protege solo las **claves**, no secretos ni certificados |
| Soft delete | Siempre activo en vaults nuevos, retención de 7 a 90 días | No se puede desactivar |
| Purge protection | Activado | Sin él, un Key Vault Contributor puede borrar y purgar todo. Es el control antiransomware |
| Red | Private endpoint + acceso público desactivado | El service endpoint deja el FQDN público; el private endpoint no |
| Detección | Defender for Key Vault | Detecta accesos anómalos; no previene nada |

No confundas Defender for Key Vault (alertas de ataques en curso) con las recomendaciones de CSPM ("el vault debería tener purge protection", "los secretos deberían caducar"). Las primeras salen en *Security alerts*; las segundas, en *Recommendations* y en el Secure Score.

```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "app" {
  name                          = "kv-tfur-stage-weu"
  resource_group_name           = azurerm_resource_group.security.name
  location                      = azurerm_resource_group.security.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard" # "premium" para claves en HSM
  rbac_authorization_enabled    = true       # obligatorio desde azurerm 5.0
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Con RBAC, quien ejecuta Terraform necesita un rol de datos para crear secretos
resource "azurerm_role_assignment" "kv_admin_pipeline" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-tfur-stage"
  resource_group_name = azurerm_resource_group.security.name
  location            = azurerm_resource_group.security.location
  subnet_id           = module.spoke.pe_subnet_id # output del módulo spoke de este entorno (cap. 4)

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.app.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id] # privatelink.vaultcore.azure.net
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_key_vault.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
```

> [!WARNING]
> **El error típico tras crear el vault** es un 403 al crear el primer secreto: con RBAC, ser Owner de la suscripción no da acceso al plano de datos. De ahí la asignación `Key Vault Secrets Officer` al propio pipeline. Por la misma razón, Key Vault Reader no lee valores: para eso está Key Vault Secrets User.

Una clave con rotación automática, que usaremos para cifrar con clave propia la cuenta del state:

```hcl
resource "azurerm_key_vault_key" "state_cmk" {
  name         = "cmk-tfstate"
  key_vault_id = azurerm_key_vault.app.id
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["wrapKey", "unwrapKey"]

  rotation_policy {
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"

    automatic {
      time_before_expiry = "P30D"
    }
  }
}
```

### Secretos y providers: cómo se autentica Terraform

*Fuentes: Libro · SC-300 sesión 11 · SC-500 cap. 01*

El libro compara variables de entorno, roles IAM y OIDC. En Azure son estas cuatro opciones:

| Opción | Cómo | Secreto guardado | Cuándo |
| --- | --- | --- | --- |
| Azure CLI | `az login` | Token en tu equipo | Trabajo local |
| Service principal con secreto o certificado | `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_SECRET` o `ARM_CLIENT_CERTIFICATE_PATH` | Sí, y caduca | Solo si no hay alternativa (certificado mejor que secreto) |
| Managed identity | `use_msi = true` + `ARM_CLIENT_ID` de la identidad | No | Runner autoalojado en una VM o en AKS dentro de Azure |
| OIDC (workload identity federation) | `use_oidc = true` | No | GitHub Actions, Azure DevOps, GitLab |

**Managed identities** \[SC-500 cap. 01\]. La *system-assigned* vive y muere con su recurso; la *user-assigned* es un recurso independiente que puedes compartir. Mi guía pone el ejemplo de 10 VMs que leen la misma cuenta de storage: con system-assigned son 10 identidades y 10 asignaciones de rol; con una user-assigned, una y una. Para "mínimo esfuerzo de administración", user-assigned. Ojo: una managed identity no sirve para APIs de terceros que solo aceptan API keys; ahí la identidad lee la key de Key Vault.

**OIDC desde GitHub Actions** \[SC-300 sesión 11\]. GitHub emite un token firmado con el repositorio y el entorno en el campo *subject*. Entra lo canjea por un token de acceso si existe una credencial federada que confíe en ese emisor y ese subject exacto. Sin secretos que rotar ni que filtrar.

```hcl
resource "azurerm_user_assigned_identity" "github_prod" {
  name                = "id-github-terraform-prod"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
}

resource "azurerm_federated_identity_credential" "github_prod" {
  name                      = "github-env-prod"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_prod.id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "repo:cristianrdgzzz/infra-live:environment:prod"
}

resource "azurerm_role_assignment" "github_prod_contributor" {
  scope                = "/subscriptions/${var.prod_subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_prod.principal_id
  principal_type       = "ServicePrincipal"
}
```

El subject debe coincidir exactamente con lo que envía GitHub; una errata hace fallar el canje sin un error claro. Las credenciales federadas clásicas no admiten comodines; si los necesitas, una app registration admite credenciales *flexibles* con expresiones (`azuread_application_flexible_federated_identity_credential`). En el pipeline basta con estas variables (el flujo completo, en el cap. 10):

```yaml
permissions:
  id-token: write   # permite pedir el token OIDC
  contents: read
env:
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### Secretos en recursos y data sources

*Fuentes: Libro · Terraform 1.10 y 1.11*

El libro propone tres vías para pasar un secreto a un recurso: variables de entorno (`TF_VAR_db_password` con `sensitive = true`), ficheros cifrados (en Azure, sops con una clave de Key Vault) o leerlo de un almacén con un data source. Las tres tienen el mismo agujero: el valor acaba en el state. Desde Terraform 1.10 y 1.11 (finales de 2024 y principios de 2025) hay dos piezas que lo resuelven:

- **Recursos efímeros** (`ephemeral`, Terraform 1.10+). Se leen o generan en cada ejecución y nunca se guardan en state ni plan.
- **Argumentos write-only** (sufijo `_wo`, Terraform 1.11+). El provider envía el valor a Azure pero no lo guarda. Como Terraform no puede comparar, se acompañan de un `_wo_version` que subes cuando quieras rotar.

Una contraseña generada, enviada al servidor y guardada en Key Vault sin pasar por el state:

```hcl
ephemeral "random_password" "sql_admin" {
  length      = 32
  special     = true
  min_upper   = 2
  min_numeric = 2
}

resource "azurerm_mssql_server" "legacy" {
  name                                    = "sql-legacy-stage-weu"
  resource_group_name                     = azurerm_resource_group.data.name
  location                                = azurerm_resource_group.data.location
  version                                 = "12.0"
  minimum_tls_version                     = "1.2"
  administrator_login                     = "sqladmin"
  administrator_login_password_wo         = ephemeral.random_password.sql_admin.result
  administrator_login_password_wo_version = 1 # súbelo para rotar
}

resource "azurerm_key_vault_secret" "sql_admin" {
  name             = "sql-admin-password"
  key_vault_id     = azurerm_key_vault.app.id
  value_wo         = ephemeral.random_password.sql_admin.result
  value_wo_version = 1 # súbelo a la vez que el del servidor
  content_type     = "password"
  expiration_date  = "2027-10-26T00:00:00Z" # recomendación de CSPM: secretos con caducidad
}
```

Y cómo leerlo desde otra configuración:

```hcl
# El vault ya existe y lo gestiona otra configuración
data "azurerm_key_vault" "app" {
  name                = "kv-tfur-stage-weu"
  resource_group_name = "rg-security-stage-weu"
}

# Mal: el valor acaba en el state
data "azurerm_key_vault_secret" "sql_admin" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.app.id
}

# Bien: se lee en cada ejecución y no se guarda
ephemeral "azurerm_key_vault_secret" "sql_admin" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.app.id
}
```

Un valor efímero solo puede usarse en sitios que tampoco se guardan: argumentos `_wo`, bloques `provider`, otras variables o locals efímeros.

**Mejor todavía: que la aplicación lea el secreto en tiempo de ejecución.** Terraform solo crea la identidad y el permiso; el valor nunca pasa por él:

```hcl
resource "azurerm_user_assigned_identity" "web" {
  name                = "id-web-stage"
  resource_group_name = azurerm_resource_group.web.name
  location            = azurerm_resource_group.web.location
}

resource "azurerm_role_assignment" "web_reads_secrets" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.web.principal_id
  principal_type       = "ServicePrincipal"
}

# Dentro del VMSS (o la VM, App Service, Function...)
identity {
  type         = "UserAssigned"
  identity_ids = [azurerm_user_assigned_identity.web.id]
}
```

### El state y los ficheros de plan

`sensitive = true` solo oculta el valor en la consola: en el state sigue en claro. Y en Azure hay atributos sensibles por todas partes: `primary_access_key` de cada Storage Account, `kube_config` de AKS, el `result` de cada `random_password` no efímero. Medidas:

- Backend con autenticación Entra, sin claves compartidas y con roles de datos mínimos (cap. 3).
- Cifrado en reposo; con clave propia si lo exige tu marco de cumplimiento (abajo).
- Private endpoint para la cuenta del state y versionado activado.
- Los ficheros de `terraform plan -out` también contienen secretos: en CI, guárdalos como artefactos cifrados y de vida corta.
- OpenTofu añade cifrado nativo del state, una de sus diferencias con Terraform.

Cifrar la cuenta del state con la clave del vault. Mi guía SC-500 lo marca como requisito: la cuenta necesita una identidad con acceso a la clave, y el vault debe tener soft delete y purge protection, porque perder la clave deja los datos inaccesibles.

```hcl
resource "azurerm_user_assigned_identity" "tfstate" {
  name                = "id-st-tfstate"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
}

resource "azurerm_role_assignment" "tfstate_cmk" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.tfstate.principal_id
  principal_type       = "ServicePrincipal"
}

# La Storage Account del cap. 3 necesita además:
# identity { type = "UserAssigned", identity_ids = [azurerm_user_assigned_identity.tfstate.id] }
resource "azurerm_storage_account_customer_managed_key" "tfstate" {
  storage_account_id        = azurerm_storage_account.tfstate.id
  key_vault_key_id          = azurerm_key_vault_key.state_cmk.id
  user_assigned_identity_id = azurerm_user_assigned_identity.tfstate.id
}
```

---

## Capítulo 7 — Trabajar con varios providers

En AWS el provider va atado a una región, así que desplegar en dos regiones exige dos providers. En Azure no: la región es el argumento `location` de cada recurso. Lo que sí exige varias copias de `azurerm` es trabajar con varias suscripciones, y lo que exige providers distintos es mezclar ARM, Entra ID y Kubernetes.

> [!NOTE]
> **Lo que vas a usar:** providers con `alias` · `configuration_aliases` · `azapi_resource` · `azurerm_container_registry` · `azurerm_kubernetes_cluster` · provider `kubernetes`

### Un solo provider

Un provider es un plugin que Terraform descarga en `terraform init`. Se identifica por una dirección del registry (`hashicorp/azurerm`, `hashicorp/azuread`, `Azure/azapi`, `microsoft/msgraph`) y una restricción de versión:

```hcl
terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.11" # cualquier 5.x a partir de 5.11, nunca 6.0
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
  }
}
```

`init` escribe las versiones exactas y sus hashes en `.terraform.lock.hcl`. Súbelo a Git para que todo el equipo y el CI usen lo mismo. Para actualizar: `terraform init -upgrade`. Si el equipo mezcla Windows, macOS y Linux, añade los hashes de todas las plataformas con `terraform providers lock -platform=windows_amd64 -platform=darwin_arm64 -platform=linux_amd64`.

### Varias copias del mismo provider

*Fuentes: Libro · AZ-104*

**Varias regiones.** Basta con cambiar `location`:

```hcl
resource "azurerm_resource_group" "weu" {
  name     = "rg-app-prod-weu"
  location = "westeurope"
}

resource "azurerm_resource_group" "neu" {
  name     = "rg-app-prod-neu"
  location = "northeurope"
}
```

Al diseñar para varias regiones, ten en cuenta las *region pairs* \[AZ-104\]. West Europe y North Europe están emparejadas: Azure escalona sus actualizaciones y algunos servicios replican entre ellas (GRS, por ejemplo). Muchas regiones nuevas no tienen pareja y se apoyan en sus 3 zonas de disponibilidad; entre ellas Spain Central (Madrid), Italy North y Poland Central. Si usas Spain Central, la replicación a otra región la decides tú.

**Varias suscripciones** (el equivalente a las varias cuentas de AWS del libro). En una landing zone típica, la red hub vive en una suscripción de conectividad y cada aplicación en la suya. Se declara un provider con `alias` por suscripción:

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.workload_subscription_id
}

provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = var.connectivity_subscription_id
}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = "vnet-hub-weu"
  resource_group_name = "rg-connectivity-weu"
}
```

Si la otra suscripción está en otro tenant, añade `auxiliary_tenant_ids` al provider (máximo 3).

**Módulos que usan varios providers.** El módulo spoke del capítulo 4 crea el peering en los dos lados: uno en la suscripción de la aplicación y otro en la del hub. El módulo declara que necesita un segundo provider con `configuration_aliases`, y quien lo llama decide cuál le pasa:

```hcl
# modules/networking/spoke/versions.tf
terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 5.0"
      configuration_aliases = [azurerm.hub]
    }
  }
}

# Dentro del módulo, el peering del lado hub usa ese provider
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = "peer-hub-to-${var.name}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.this.id
  allow_forwarded_traffic   = true
}
```

```hcl
# live/prod/network/main.tf
module "spoke_prod" {
  source = "../../../modules/networking/spoke"

  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }

  name                    = "app-prod"
  resource_group_name     = azurerm_resource_group.weu.name
  location                = "westeurope"
  address_space           = ["10.20.0.0/16"]
  web_subnet_prefix       = "10.20.1.0/24"
  pe_subnet_prefix        = "10.20.2.0/24"
  hub_vnet_id             = data.azurerm_virtual_network.hub.id
  hub_vnet_name           = data.azurerm_virtual_network.hub.name
  hub_resource_group_name = "rg-connectivity-weu"
  firewall_private_ip     = "10.0.1.4"
  private_dns_zone_ids    = {}
}
```

La identidad del pipeline necesita permisos en las dos suscripciones; en la del hub, lo mínimo para crear peerings (Network Contributor sobre la VNet hub).

### Varios providers distintos

En Azure esto pasa desde el primer día, porque identidad y recursos van por APIs distintas:

| Combinación | Para qué |
| --- | --- |
| `azurerm` + `azuread` | Crear un grupo en Entra y darle un rol de Azure en la misma configuración |
| `azurerm` + `azapi` | Usar una propiedad o un tipo de recurso que azurerm aún no soporta |
| `azuread` + `msgraph` | Gobernanza que azuread no cubre, como las access reviews (Apéndice B) |
| `azurerm` + `kubernetes` + `helm` | Crear AKS y desplegar aplicaciones dentro (abajo) |

`azapi_resource` habla directamente con la API de ARM: indicas el tipo con su versión de API y el cuerpo en HCL. Es la vía de escape para servicios en preview o recién lanzados:

```hcl
resource "azapi_resource" "example" {
  type      = "Microsoft.ContainerRegistry/registries@2020-11-01-preview"
  name      = "registry1"
  parent_id = azurerm_resource_group.weu.id
  location  = azurerm_resource_group.weu.location

  body = {
    sku = {
      name = "Standard"
    }
    properties = {
      adminUserEnabled = false
    }
  }
}
```

### Curso rápido de Docker y Kubernetes

Un contenedor empaqueta la aplicación con sus dependencias en una imagen que corre igual en cualquier sitio. Kubernetes orquesta contenedores sobre un clúster de nodos: tú declaras objetos (Deployment, Service, ServiceAccount) y el plano de control los mantiene. En Azure, el registro de imágenes es **Azure Container Registry (ACR)** y el Kubernetes gestionado es **AKS**, donde Microsoft opera el plano de control y tú los nodos.

### Desplegar contenedores en AKS

*Fuentes: Libro · SC-500 cap. 14*

El libro despliega EKS y luego una app en él. Aquí, AKS con los controles de mi guía del SC-500:

| Control | Qué dice mi guía | En Terraform |
| --- | --- | --- |
| Autorización | Kubernetes RBAC (RoleBinding en YAML) y Azure RBAC for Kubernetes (asignaciones en IAM) pueden convivir. Con Azure RBAC y las cuentas locales desactivadas, todo pasa por Entra | `azure_rbac_enabled = true`, `local_account_disabled = true` |
| Identidad de pods | Microsoft Entra Workload ID sustituye a la retirada AAD Pod Identity | `oidc_issuer_enabled`, `workload_identity_enabled` + credencial federada |
| Plano de control | Authorized IP ranges, clúster privado o API Server VNet Integration. IPs autorizadas y clúster privado son incompatibles | `api_server_access_profile`, `private_cluster_enabled` |
| Red entre pods | Sin NetworkPolicy, todos los pods se hablan. Cilium es el motor recomendado (capa 7 y filtrado por FQDN) | `network_policy = "cilium"` |
| Admisión | Azure Policy para Kubernetes (Gatekeeper/OPA): primero Audit, luego Deny | `azure_policy_enabled = true` |
| Amenazas | Defender for Containers: escaneo de imágenes y postura sin agente; detección en runtime con el sensor | Bloque `microsoft_defender` |
| ACR | Usuario admin desactivado. AcrPull para el kubelet. Red y private endpoint solo en Premium | `admin_enabled = false`, `sku = "Premium"` |

```hcl
resource "azurerm_container_registry" "this" {
  name                          = "acrtfurprodweu"
  resource_group_name           = azurerm_resource_group.weu.name
  location                      = azurerm_resource_group.weu.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false # acceso por private endpoint
}

resource "azurerm_kubernetes_cluster" "this" {
  name                      = "aks-tfur-prod-weu"
  resource_group_name       = azurerm_resource_group.weu.name
  location                  = azurerm_resource_group.weu.location
  dns_prefix                = "aks-tfur-prod"
  sku_tier                  = "Standard" # SLA de disponibilidad
  automatic_upgrade_channel = "stable"
  node_os_upgrade_channel   = "NodeImage"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = true
  azure_policy_enabled      = true

  node_provisioning_profile { # obligatorio desde azurerm 5.0
    mode = "Manual"
  }

  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D4s_v5"
    auto_scaling_enabled = true
    min_count            = 2
    max_count            = 5
    vnet_subnet_id       = azurerm_subnet.aks.id
    zones                = ["1", "2", "3"]

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.admin_cidrs
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.security.id
    msi_auth_for_monitoring_enabled = true
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_admins" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.aks_admins.object_id
  principal_type       = "Group"
}

# Workload ID: el pod se autentica como esta identidad, sin secretos
resource "azurerm_user_assigned_identity" "orders_api" {
  name                = "id-orders-api"
  resource_group_name = azurerm_resource_group.weu.name
  location            = azurerm_resource_group.weu.location
}

resource "azurerm_federated_identity_credential" "orders_api" {
  name                      = "aks-orders-api"
  user_assigned_identity_id = azurerm_user_assigned_identity.orders_api.id
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:orders:orders-api"
}
```

Y ahora el segundo provider, `kubernetes`, configurado a partir del clúster. Como las cuentas locales están desactivadas, se autentica con Entra a través de `kubelogin`:

```hcl
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
  }
}

resource "kubernetes_namespace_v1" "orders" {
  metadata {
    name = "orders"
  }
}

resource "kubernetes_service_account_v1" "orders_api" {
  metadata {
    name      = "orders-api"
    namespace = kubernetes_namespace_v1.orders.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.orders_api.client_id
    }
  }
}

resource "kubernetes_deployment_v1" "orders_api" {
  metadata {
    name      = "orders-api"
    namespace = kubernetes_namespace_v1.orders.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "orders-api" }
    }

    template {
      metadata {
        labels = {
          app                           = "orders-api"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.orders_api.metadata[0].name

        container {
          name  = "api"
          image = "${azurerm_container_registry.this.login_server}/orders-api:1.0.0"

          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "orders_api" {
  metadata {
    name      = "orders-api"
    namespace = kubernetes_namespace_v1.orders.metadata[0].name
  }

  spec {
    selector = { app = "orders-api" }
    type     = "LoadBalancer"

    port {
      port        = 80
      target_port = 8080
    }
  }
}
```

El propio libro avisa de una limitación: un provider configurado con atributos de recursos que aún no existen puede fallar en el primer `plan` y complica los `destroy`. En producción, separa el clúster y las aplicaciones en dos configuraciones (dos states), y despliega las aplicaciones con Helm o GitOps (Flux, Argo CD).

---

## Capítulo 8 — Código de Terraform para producción

Llevar infraestructura a producción tarda mucho más de lo que parece, y el libro lo resuelve con una checklist y con módulos pequeños, componibles, testeables y versionados. En Azure, buena parte de esa checklist son guardarraíles de plataforma (Policy, Defender, logs, backup, Conditional Access, PIM) que también se escriben en Terraform.

> [!NOTE]
> **Lo que vas a usar:** `azurerm_policy_definition` · `azurerm_management_group_policy_assignment` · `azurerm_management_lock` · `azurerm_security_center_subscription_pricing` · `azurerm_monitor_diagnostic_setting` · `azurerm_recovery_services_vault` · `azuread_conditional_access_policy` · `azurerm_pim_eligible_role_assignment`

### Por qué tarda tanto

Según las estimaciones del libro, un servicio gestionado listo para producción lleva 1–2 semanas, uno propio sin estado 2–4 semanas, uno con estado 2–4 meses y una arquitectura completa de 6 a 36 meses. Las causas: herramientas aún inmaduras, el *yak shaving* (cada tarea destapa otra) y una larga lista de requisitos que nadie escribe. De ahí la checklist.

### La checklist de infraestructura de producción

| Tarea | Qué incluye | Servicio o recurso en Azure |
| --- | --- | --- |
| Instalar | Binarios y dependencias | Packer → Azure Compute Gallery, cloud-init |
| Configurar | Puertos, TLS, replicación | cloud-init, Azure Machine Configuration, App Configuration |
| Aprovisionar | Servidores, red, firewall, permisos | Terraform (`azurerm`, `azuread`) |
| Desplegar | Actualizaciones sin caída | VMSS rolling upgrade, deployment slots, AKS |
| Alta disponibilidad | Sobrevivir a caídas de servidor, zona o región | Zonas de disponibilidad, ZRS/GZRS, segunda región |
| Escalabilidad | Escalar según la carga | Autoscale de Azure Monitor, cluster autoscaler de AKS |
| Rendimiento | CPU, memoria, red | Application Insights, Azure Load Testing |
| Red | IPs, DNS, firewall, VPN | VNet, NSG, Azure Firewall, Private DNS, VPN Gateway |
| Seguridad | Cifrado, autenticación, autorización, secretos, hardening | Entra ID, RBAC, Key Vault, Defender for Cloud, Azure Policy |
| Métricas | Disponibilidad, negocio, alertas | Azure Monitor, alertas, Managed Grafana |
| Logs | Centralizar logs | Log Analytics, diagnostic settings, Sentinel |
| Backup | Copias programadas y en otra región | Azure Backup, Recovery Services vault, Backup vault |
| Optimización de costes | Tamaños correctos, reservas, limpieza | Cost Management, budgets, Advisor, Spot |
| Documentación | Código, arquitectura, runbooks | READMEs, wiki de Azure DevOps |
| Tests | Tests automáticos de la infraestructura | `terraform test`, Terratest, tflint, Checkov (cap. 9) |

### Módulos pequeños

Un módulo enorme es lento, arriesgado y difícil de entender y de testear. El clúster del capítulo 4 hacía de todo; en producción conviene partirlo en piezas que hagan una sola cosa: `networking/spoke`, `compute/vmss`, `networking/lb`, `security/keyvault`.

### Módulos componibles

Como funciones: reciben todo por variables, devuelven todo por outputs y no tienen efectos ocultos. Así se combinan en el root module: el output `web_subnet_id` del módulo de red entra como `subnet_id` en el de cómputo, y el `backend_pool_id` del load balancer entra en el VMSS.

### Módulos testeables

Cada módulo lleva una carpeta `examples/` que lo despliega con valores reales; esos ejemplos son la base de los tests del capítulo 9. Además, Terraform permite validar dentro del propio código:

| Mecanismo | Cuándo se evalúa | Para qué |
| --- | --- | --- |
| `validation` en variables | Al leer la variable | Rechazar entradas inválidas |
| `precondition` | Antes de crear o cambiar el recurso | Comprobar supuestos que relacionan varias entradas |
| `postcondition` | Después, con `self` | Garantizar algo del recurso creado |
| Bloque `check` (1.5+) | Al final de cada plan y apply, sin bloquear | Comprobaciones continuas, como que la web responda |

```hcl
variable "vm_size" {
  type = string

  validation {
    condition     = can(regex("^Standard_(B|D|E)", var.vm_size))
    error_message = "Solo se permiten tamaños de las series B, D o E."
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  # ...
  secure_boot_enabled = true
  vtpm_enabled        = true

  lifecycle {
    precondition {
      condition     = var.min_size <= var.max_size
      error_message = "min_size no puede ser mayor que max_size."
    }

    postcondition {
      condition     = self.secure_boot_enabled && self.vtpm_enabled
      error_message = "El VMSS debe desplegarse con Trusted Launch."
    }
  }
}

check "web_responde" {
  data "http" "lb" {
    url = "http://${azurerm_public_ip.lb.ip_address}"
  }

  assert {
    condition     = data.http.lb.status_code == 200
    error_message = "El load balancer no devuelve 200."
  }
}
```

### Módulos versionados

Versiona las cuatro piezas:

| Pieza | Cómo fijarla |
| --- | --- |
| Terraform | `required_version = "~> 1.17.0"` y un fichero `.terraform-version` por entorno para `tfenv` |
| Providers | `version = "~> 5.11"` en `required_providers` + `.terraform.lock.hcl` en Git. Desde la 1.17 la versión puede venir de una variable o local |
| Módulos | `?ref=v1.4.0` en Git o `version = "1.4.0"` en un registry |
| Herramientas de alrededor | Terragrunt (o la alternativa OpenTofu) con su versión fijada |

Si publicas en un registry, respeta el nombre `terraform-azurerm-<nombre>` y la estructura estándar (`main.tf`, `variables.tf`, `outputs.tf`, `README.md`, `examples/`).

### Más allá de los módulos

El libro repasa las vías de escape. **Provisioners** (`remote-exec`, `local-exec`): último recurso; en Azure, mejor `custom_data`, extensiones de VM o imágenes con Packer. **`terraform_data`**: sustituye a `null_resource` para lanzar acciones cuando algo cambia. **Data source `external`**: ejecuta un script y lee su JSON. Desde Terraform 1.14 hay una cuarta: los **actions**, operaciones que define el provider fuera del CRUD normal; azurerm ya trae algunos, como encender o apagar una VM (`azurerm_virtual_machine_power`).

### Guardarraíles de Azure en código

*Fuentes: SC-500 · SC-300*

Esta parte no está en el libro, pero es la que convierte "funciona" en "pasa una auditoría". Cada bloque sale de los capítulos y checklists de mis guías.

#### Azure Policy

*Fuente: SC-500 cap. 03*

RBAC decide **quién** puede hacer algo; Policy decide **cómo** debe quedar lo que se despliega. Una definición es un *if/then* en JSON que no hace nada hasta que la asignas a un ámbito (management group, suscripción o resource group), y la asignación se hereda hacia abajo, incluidas las suscripciones futuras.

| Efecto | Qué hace | Cuándo actúa |
| --- | --- | --- |
| `Disabled` | Nada | — |
| `Audit` / `AuditIfNotExists` | Marca como no conforme | Después del despliegue |
| `Deny` | Bloquea el despliegue | Antes del despliegue |
| `Append` / `Modify` | Añade o cambia propiedades o tags | Antes, y con tarea de remediación |
| `DeployIfNotExists` | Despliega un recurso relacionado que falta | Después, y con tarea de remediación |

Las reglas de mi guía: las iniciativas agrupan políticas (Defender for Cloud usa el Microsoft Cloud Security Benchmark); empieza en `Audit` y pasa a `Deny` tras revisar el impacto; el efecto debe ser un parámetro; los recursos existentes solo se corrigen con una *remediation task*, que necesita una identidad en la asignación; y una definición integrada no se modifica, se duplica.

```hcl
data "azurerm_management_group" "root" {
  name = var.tenant_id # el management group raíz se llama como el tenant
}

# Comprueba el nombre exacto con: az policy set-definition list --query "[].displayName"
data "azurerm_policy_set_definition" "mcsb" {
  display_name = "Microsoft cloud security benchmark"
}

resource "azurerm_management_group_policy_assignment" "mcsb" {
  name                 = "mcsb"
  display_name         = "Microsoft cloud security benchmark"
  management_group_id  = data.azurerm_management_group.root.id
  policy_definition_id = data.azurerm_policy_set_definition.mcsb.id
}

resource "azurerm_policy_definition" "require_owner_tag" {
  name                = "require-owner-tag-rg"
  policy_type         = "Custom"
  mode                = "All"
  display_name        = "Los resource groups deben tener la etiqueta owner"
  management_group_id = data.azurerm_management_group.root.id

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Resources/subscriptions/resourceGroups" },
        { field = "tags['owner']", exists = "false" }
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}

resource "azurerm_management_group_policy_assignment" "require_owner_tag" {
  name                 = "req-owner-tag"
  management_group_id  = data.azurerm_management_group.root.id
  policy_definition_id = azurerm_policy_definition.require_owner_tag.id

  parameters = jsonencode({
    effect = { value = "Audit" } # pasa a "Deny" tras revisar el cumplimiento
  })

  non_compliance_message {
    content = "Añade la etiqueta owner al resource group."
  }
}
```

Para políticas `DeployIfNotExists` o `Modify`, añade a la asignación un bloque `identity` (y `location`), dale a esa identidad el rol que necesite y crea la remediación con `azurerm_management_group_policy_remediation`.

#### Resource locks

*Fuente: SC-500 cap. 03*

`CanNotDelete` permite leer y modificar pero no borrar; `ReadOnly` solo permite leer. Actúan en el **plano de control**: un lock en una Storage Account no impide escribir blobs. Quitar un lock exige `Microsoft.Authorization/locks/delete`, que tienen Owner y User Access Administrator pero **no** Contributor. Cuidado con `ReadOnly`: operaciones como listar claves cuentan como escritura y fallan.

```hcl
resource "azurerm_management_lock" "kv" {
  name       = "no-borrar"
  scope      = azurerm_key_vault.app.id
  lock_level = "CanNotDelete"
  notes      = "Key Vault de producción"
}

resource "azurerm_management_lock" "law" {
  name       = "no-borrar"
  scope      = azurerm_log_analytics_workspace.security.id
  lock_level = "CanNotDelete"
  notes      = "Logs de seguridad"
}
```

Un lock también bloquea a Terraform: un `destroy` fallará hasta que lo quites. Es justo lo que quieres en producción.

#### Microsoft Defender for Cloud

*Fuente: SC-500 caps. 02, 06, 13 y 16*

Defender for Cloud tiene dos mitades. **CSPM** evalúa la configuración: el Foundational CSPM es gratis y siempre está activo (Secure Score y MCSB); el **Defender CSPM** es de pago y añade attack path analysis, cloud security explorer, escaneo sin agente y CIEM. **CWPP** son los planes de protección por tipo de recurso, que detectan ataques en curso. Lo que mi guía marca:

- Defender for Servers Plan 2 es obligatorio para JIT, FIM y escaneo sin agente; el Plan 1 se centra en el EDR de Defender for Endpoint.
- Defender for Storage escanea malware al subir, con un límite mensual por cuenta (10.000 GB por defecto); al alcanzarlo, los ficheros nuevos dejan de escanearse ese mes.
- Defender for Key Vault detecta, no previene.
- Añadir estándares de cumplimiento (ISO 27001, PCI-DSS) no cambia el Secure Score.

```hcl
locals {
  defender_plans = {
    VirtualMachines = "P2" # JIT, FIM y escaneo sin agente requieren Plan 2
    StorageAccounts = "DefenderForStorageV2"
    KeyVaults       = null
    Arm             = null
    SqlServers      = null
    Containers      = null
    CloudPosture    = null # Defender CSPM
  }
}

resource "azurerm_security_center_subscription_pricing" "this" {
  for_each = local.defender_plans

  resource_type = each.key
  tier          = "Standard"
  subplan       = each.value
}

resource "azurerm_security_center_contact" "soc" {
  name                = "default"
  email               = "soc@contoso.com"
  alert_notifications = true
  alerts_to_admins    = true
}
```

Las extensiones de cada plan (por ejemplo `OnUploadMalwareScanning` en Storage o `AgentlessVmScanning` en CloudPosture) se activan con bloques `extension { name = "..." }` dentro del mismo recurso.

#### Logs y métricas

*Fuentes: SC-300 sesión 17 · SC-500 caps. 08 y 10*

Todo debe acabar en un Log Analytics workspace. Tres fuentes que se olvidan a menudo:

- **Activity log de la suscripción**: quién cambió qué en ARM.
- **Logs de Entra ID**: el portal solo guarda 7 días (Free) o 30 (P1/P2). Para más, diagnostic settings hacia Log Analytics, Storage o Event Hubs. Recuerda que hay varias tablas: `SigninLogs`, `NonInteractiveUserSignInLogs`, `ServicePrincipalSignInLogs`, `ManagedIdentitySignInLogs` y `AuditLogs`.
- **Flow logs de red**: desde el 30 de junio de 2025 no se pueden crear NSG flow logs nuevos y se retiran el 30 de septiembre de 2027. Usa **VNet flow logs**.

```hcl
resource "azurerm_log_analytics_workspace" "security" {
  name                = "log-security-prod-weu"
  resource_group_name = azurerm_resource_group.security.name
  location            = azurerm_resource_group.security.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "activity-to-law"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }
}

resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  name                       = "entra-to-law"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  enabled_log {
    category = "SignInLogs"
  }

  enabled_log {
    category = "NonInteractiveUserSignInLogs"
  }

  enabled_log {
    category = "ServicePrincipalSignInLogs"
  }

  enabled_log {
    category = "ManagedIdentitySignInLogs"
  }

  enabled_log {
    category = "AuditLogs"
  }
}

resource "azurerm_network_watcher_flow_log" "vnet" {
  name                 = "fl-vnet-app-prod"
  network_watcher_name = "NetworkWatcher_westeurope"
  resource_group_name  = "NetworkWatcherRG"
  target_resource_id   = module.spoke_prod.vnet_id # la VNet, no un NSG
  storage_account_id   = azurerm_storage_account.flowlogs.id
  enabled              = true
  version              = 2

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.security.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.security.location
    workspace_resource_id = azurerm_log_analytics_workspace.security.id
    interval_in_minutes   = 10
  }
}
```

El `azurerm_monitor_diagnostic_setting` del Key Vault (cap. 6) es el patrón para cada recurso. Para no escribirlo cien veces, una política `DeployIfNotExists` puede crearlos automáticamente. Sentinel se monta encima de este workspace (Apéndice C).

#### Backup

*Fuente: SC-500 cap. 05*

Mi guía insiste en que cada capa para una amenaza distinta y ninguna basta sola:

| Capa | Para | No para |
| --- | --- | --- |
| Soft delete (activo por defecto, 14–180 días) | Borrados accidentales | A un admin que la desactive, salvo que sea *always-on* |
| Vault inmutable: Disabled, Enabled o Enabled and locked | Que se reduzca la retención o se borren puntos de restauración | Solo *locked* es irreversible y resiste a un Owner comprometido |
| Multi-User Authorization (Resource Guard) | Que un solo admin debilite las protecciones | Si el admin del vault también gestiona el Resource Guard |
| GRS + Cross Region Restore | Caída de la región | — |

```hcl
resource "azurerm_recovery_services_vault" "prod" {
  name                          = "rsv-prod-weu"
  resource_group_name           = azurerm_resource_group.backup.name
  location                      = azurerm_resource_group.backup.location
  sku                           = "Standard"
  storage_mode_type             = "GeoRedundant"
  cross_region_restore_enabled  = true
  immutability                  = "Unlocked" # valida y luego "Locked" (irreversible)
  public_network_access_enabled = false
}

resource "azurerm_backup_policy_vm" "daily" {
  name                = "bkpol-vm-daily"
  resource_group_name = azurerm_resource_group.backup.name
  recovery_vault_name = azurerm_recovery_services_vault.prod.name
  policy_type         = "V2"
  timezone            = "Romance Standard Time"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }
}

resource "azurerm_backup_protected_vm" "web01" {
  resource_group_name = azurerm_resource_group.backup.name
  recovery_vault_name = azurerm_recovery_services_vault.prod.name
  source_vm_id        = azurerm_linux_virtual_machine.web.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# MUA: el Resource Guard vive en otra suscripción y lo gestiona otro equipo
resource "azurerm_data_protection_resource_guard" "this" {
  provider            = azurerm.security
  name                = "rg-guard-backup"
  resource_group_name = "rg-resource-guards"
  location            = "westeurope"
}

resource "azurerm_recovery_services_vault_resource_guard_association" "this" {
  vault_id          = azurerm_recovery_services_vault.prod.id
  resource_guard_id = azurerm_data_protection_resource_guard.this.id
}
```

Azure Backup protege VMs individuales y VMSS Flexible, pero no VMSS Uniform. Para restaurar hacen falta dos roles: Backup Operator en el vault y, por ejemplo, Virtual Machine Contributor en la VM de destino.

#### Conditional Access

*Fuente: SC-300 sesión 07*

Una política es un *if/then*: las asignaciones (usuarios, aplicaciones, condiciones) se combinan con AND, y si aplican varias políticas, hay que cumplirlas todas. `Block` gana a cualquier `Grant`. Las reglas de mi guía para desplegarlas sin quedarte fuera:

- Empieza siempre en *report-only* (`enabledForReportingButNotEnforced`) y revisa los sign-in logs o la herramienta What If.
- Excluye las cuentas *break-glass* de todas las políticas; las plantillas no lo hacen por ti.
- Para administradores, *authentication strength* resistente al phishing en vez de un simple "Require MFA" (no se pueden usar las dos en la misma política).
- Security defaults y Conditional Access son excluyentes.

```hcl
data "azuread_authentication_strength_policy" "phishing_resistant" {
  display_name = "Phishing-resistant MFA"
}

resource "azuread_conditional_access_policy" "admins_phish_resistant" {
  display_name = "CA001-Admins-AllApps-PhishingResistantMFA"
  state        = "enabledForReportingButNotEnforced" # report-only primero

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_roles = [
        "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
        "e8611ab8-c189-46e8-94e1-60213ab1f814", # Privileged Role Administrator
      ]
      excluded_users = var.break_glass_object_ids
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = data.azuread_authentication_strength_policy.phishing_resistant.id
  }
}

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "CA002-AllUsers-AllApps-BlockLegacyAuth"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = var.break_glass_object_ids
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
```

El nombre sigue la convención de mi guía: `[ID]-[Destinatarios]-[Apps]-[Control]`. Conditional Access exige Entra ID P1; las condiciones de riesgo (`sign_in_risk_levels`, `user_risk_levels`) exigen P2.

#### Privileged Identity Management

*Fuentes: SC-300 sesión 16 · SC-500 caps. 01 y 04*

PIM sustituye el acceso permanente por acceso *just-in-time*. Una asignación **eligible** no da permisos hasta que el usuario la activa (con MFA, justificación y, si se exige, aprobación); una **active** los da desde el primer momento. La configuración se define por rol y aplica a todas sus asignaciones. Recuerda la diferencia de permisos: los roles de Entra los gestiona un Privileged Role Administrator, pero los roles de Azure necesitan Owner o User Access Administrator en ese ámbito.

```hcl
data "azurerm_subscription" "current" {}

data "azurerm_role_definition" "owner" {
  name  = "Owner"
  scope = data.azurerm_subscription.current.id
}

# Reglas de activación del rol Owner en esta suscripción
resource "azurerm_role_management_policy" "owner" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = data.azurerm_role_definition.owner.id

  activation_rules {
    maximum_duration                   = "PT4H"
    require_approval                   = true
    require_justification              = true
    require_multifactor_authentication = true

    approval_stage {
      primary_approver {
        object_id = azuread_group.pim_approvers.object_id
        type      = "Group"
      }
    }
  }

  eligible_assignment_rules {
    expiration_required = true
    expire_after        = "P180D"
  }
}

resource "time_static" "now" {}

# Rol de Azure: el grupo de seguridad es eligible para Owner
resource "azurerm_pim_eligible_role_assignment" "owner_secops" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = "${data.azurerm_subscription.current.id}${data.azurerm_role_definition.owner.id}"
  principal_id       = azuread_group.this["grp-security-team"].object_id
  justification      = "Acceso JIT de operaciones de seguridad"

  schedule {
    start_date_time = time_static.now.rfc3339

    expiration {
      duration_days = 180
    }
  }
}

# Rol de Entra: Trinity es eligible para Global Administrator
resource "azuread_directory_role" "global_admin" {
  display_name = "Global Administrator"
}

resource "azuread_directory_role_eligibility_schedule_request" "trinity_ga" {
  role_definition_id = azuread_directory_role.global_admin.template_id
  principal_id       = azuread_user.this["trinity"].object_id
  directory_scope_id = "/"
  justification      = "Administración del tenant con activación JIT"
}
```

> [!CAUTION]
> **El escenario de bloqueo que describe mi guía:** si todos los administradores son eligible, la activación exige aprobación y no hay aprobadores, nadie puede administrar el tenant. Mantén siempre dos cuentas break-glass con asignación **active** permanente, fuera de Terraform o protegidas con `prevent_destroy`, y al menos dos aprobadores.

PIM requiere Entra ID P2 o ID Governance.

---

## Capítulo 9 — Cómo testear código de Terraform

En infraestructura no hay *localhost*: la única forma fiable de saber si el código funciona es desplegarlo de verdad en un entorno aislado y destruirlo después. El libro lo hace con Terratest (Go). Desde Terraform 1.6 también tienes `terraform test`, nativo y en HCL, con *mocks* para tests unitarios sin tocar Azure.

> [!NOTE]
> **Lo que vas a usar:** `terraform test` con `mock_provider` · Terratest · TFLint · Checkov · Trivy · OPA/Conftest · Terraform Policy

### Tests manuales

**Lo básico.** Despliega el módulo desde su carpeta `examples/`, compruébalo (con `curl` a la IP del load balancer, por ejemplo) y destrúyelo. El libro insiste en hacerlo en un entorno de pruebas propio, nunca en stage ni en prod.

**Limpiar después de los tests.** En Azure es más fácil que en AWS porque todo vive en resource groups:

- Una suscripción sandbox por desarrollador o por equipo, separada de stage y prod, con presupuesto y alertas.
- Un resource group por test, con nombre único y una etiqueta de caducidad (por ejemplo `expires-on`).
- Una limpieza programada que borre los resource groups caducados. Una política `Deny` que exija la etiqueta evita que se te olvide ponerla.

### Tests automáticos

El libro distingue tres niveles, de más rápidos y baratos a más lentos y completos:

| Nivel | Qué prueba | Herramienta en Azure | Tiempo típico |
| --- | --- | --- | --- |
| Unitario | Un módulo aislado | `terraform test` con `mock_provider`, o Terratest contra una sandbox | Segundos (mock) a minutos (real) |
| Integración | Varios módulos juntos (red + cómputo + datos) | `terraform test` con varios `run`, Terratest por etapas | Decenas de minutos |
| End-to-end | Toda la arquitectura | Un entorno de test persistente con despliegues incrementales | Horas |

La recomendación es la pirámide: muchos tests unitarios, menos de integración y pocos end-to-end.

### Tests unitarios

*Fuentes: Libro · Terraform 1.6+*

**Con `terraform test`.** Los ficheros `*.tftest.hcl` contienen bloques `run`. Cada `run` hace `plan` o `apply` y comprueba con `assert`. Con `mock_provider`, Terraform no llama a Azure: sirve para probar la lógica del módulo (nombres, condicionales, validaciones) en segundos.

```hcl
# modules/services/webserver-cluster/tests/unit.tftest.hcl
mock_provider "azurerm" {}

variables {
  cluster_name        = "web-test"
  resource_group_name = "rg-test"
  location            = "westeurope"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-web"
  vm_size             = "Standard_B1s"
  min_size            = 2
  max_size            = 4
  ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEjemploSoloParaTests test@example"
}

run "nombres_y_puertos" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.name == "vmss-web-test"
    error_message = "El VMSS no sigue la convención de nombres."
  }

  assert {
    condition     = azurerm_lb_rule.http.frontend_port == 80
    error_message = "El load balancer debe escuchar en el puerto 80."
  }
}

# Comprueba que la validación del cap. 8 rechaza tamaños no permitidos
run "rechaza_tamanos_no_permitidos" {
  command = plan

  variables {
    vm_size = "Standard_M128s"
  }

  expect_failures = [var.vm_size]
}
```

```bash
terraform test                 # ejecuta todos los *.tftest.hcl
terraform test -parallelism=4  # Terraform 1.12+
```

**Con Terratest**, como en el libro. Es una librería de Go que ejecuta Terraform de verdad y te deja comprobar cualquier cosa con código (peticiones HTTP con reintentos, SSH, llamadas al SDK de Azure). La versión 1.x mantiene la API clásica del libro; ya hay una 2.0 con módulos separados y funciones con `context`, así que fija la versión en tu `go.mod`.

```go
// test/webserver_cluster_test.go
package test

import (
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebserverCluster(t *testing.T) {
	t.Parallel() // cada test usa nombres únicos, así que pueden ir en paralelo

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/webserver-cluster",
		Vars: map[string]any{
			"cluster_name": fmt.Sprintf("web-%s", random.UniqueID()),
		},
	})

	defer terraform.Destroy(t, opts) // limpia aunque el test falle
	terraform.InitAndApply(t, opts)

	ip := terraform.Output(t, opts, "lb_public_ip")
	http_helper.HttpGetWithRetry(t, "http://"+ip, nil, 200, "Hola, mundo\n", 30, 10*time.Second)
}
```

El libro añade dos técnicas que siguen vigentes. **Inyección de dependencias:** que el módulo reciba por variable lo que en producción leería de otro state (la subred, la base de datos), para poder pasarle valores de test. **Paralelismo:** `t.Parallel()` y nombres únicos en todos los recursos, porque dos tests no pueden crear el mismo Key Vault o la misma Storage Account.

### Tests de integración

Un test de integración despliega varios módulos que dependen entre sí. Con `terraform test` se encadenan `run` que reutilizan los outputs de los anteriores; al final, Terraform destruye todo en orden inverso:

```hcl
# tests/integration.tftest.hcl
provider "azurerm" {
  features {}
}

run "red_de_prueba" {
  module {
    source = "./tests/setup" # crea un RG y una subred efímeros
  }
}

run "despliega_cluster" {
  command = apply

  variables {
    resource_group_name = run.red_de_prueba.resource_group_name
    subnet_id           = run.red_de_prueba.subnet_id
  }
}

run "responde_http" {
  command = plan

  module {
    source = "./tests/http"
  }

  variables {
    url = "http://${run.despliega_cluster.lb_public_ip}"
  }

  assert {
    condition     = data.http.check.status_code == 200
    error_message = "El clúster no responde con 200."
  }
}
```

```hcl
# tests/http/main.tf: módulo auxiliar que hace la petición con reintentos
variable "url" {
  type = string
}

data "http" "check" {
  url = var.url

  retry {
    attempts     = 20
    min_delay_ms = 10000 # cloud-init tarda en arrancar el servidor
  }
}
```

El libro añade **etapas** (en Terratest, `test_structure.RunTestStage`) para poder saltarte el despliegue mientras iteras sobre las comprobaciones, y **reintentos** para errores conocidos y transitorios. En Azure los más habituales son la replicación de Entra, los límites de peticiones de ARM y la propagación de asignaciones RBAC, que puede tardar unos minutos.

### Tests end-to-end

Desplegar toda la arquitectura desde cero para cada test es demasiado lento. El libro propone un entorno de test persistente donde cada cambio se aplica de forma incremental, como harías en producción. Así también pruebas el propio proceso de despliegue.

### Otras formas de testear

*Fuentes: Libro · SC-500 cap. 03*

**Análisis estático.** Lee el código sin desplegar nada. Es lo primero que debe ejecutar cualquier pipeline:

| Herramienta | Qué detecta |
| --- | --- |
| `terraform fmt -check` y `terraform validate` | Formato, sintaxis y referencias rotas |
| TFLint 0.65 con el plugin `azurerm` 0.33 | Valores inválidos específicos de Azure (tamaños de VM, SKUs) y malas prácticas |
| Checkov 3.x | Configuraciones inseguras: storage con acceso público, Key Vault sin purge protection, NSG abiertos… |
| Trivy (`trivy config .`) | Lo mismo; incluye las reglas del antiguo tfsec |

```hcl
# .tflint.hcl
plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
```

**Tests del plan (policy as code).** Generas el plan en JSON y lo evalúas con reglas. Con OPA/Conftest y Rego:

```bash
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
conftest test plan.json -p policy/
```

```rego
# policy/storage.rego
package main

import rego.v1

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  rc.change.after.shared_access_key_enabled == true
  msg := sprintf("%s: desactiva las claves compartidas", [rc.address])
}
```

Alternativas: Terraform Policy, que es GA desde Terraform 1.17 (`terraform plan -policies=<carpeta>`), y Sentinel u OPA en HCP Terraform. Mi guía del SC-500 añade un matiz: la acción de GitHub de Azure Policy hace un escaneo de cumplimiento *después* de desplegar. Para bloquear *antes*, necesitas estas herramientas de análisis del plan. Y si Azure Policy tiene una regla `Deny`, el despliegue fallará en ARM venga de donde venga.

**Tests de servidor.** Comprueban lo que hay dentro de la VM: paquetes, servicios, puertos. El libro menciona InSpec, Serverspec y Goss; en Azure, Machine Configuration (Azure Policy dentro del sistema operativo) audita lo mismo de forma continua.

---

## Capítulo 10 — Terraform en equipo

En equipo, nadie ejecuta `terraform apply` desde su portátil contra producción: los cambios entran por pull request, el pipeline hace `plan` para revisarlos y, tras el merge, el `apply` lo ejecuta una identidad sin secretos que solo existe para eso. En Azure esa identidad es una managed identity con OIDC y mínimo privilegio.

> [!NOTE]
> **Lo que vas a usar:** bloques `import` · `terraform query` · `aztfexport` · `azurerm_user_assigned_identity` · `azurerm_federated_identity_credential` · GitHub Actions o Azure DevOps

### Adoptar IaC en el equipo

El libro da tres consejos. **Convence a tu jefe** hablando de resultados (menos caídas, despliegues más rápidos, auditoría), no de herramientas. **Avanza poco a poco:** empieza por algo pequeño que duela. **Da tiempo al equipo para aprender**, o volverán al portal en cuanto haya prisa.

En Azure casi nunca empiezas de cero: hay recursos creados a mano. Para traerlos a Terraform:

| Herramienta | Qué hace |
| --- | --- |
| Bloques `import` + `terraform plan -generate-config-out=generated.tf` | Importa recursos concretos y escribe el código de partida (Terraform 1.5+) |
| `terraform query` con bloques `list` (Terraform 1.14+) | Descubre recursos existentes por tipo y genera la configuración para importarlos. azurerm ya trae más de cien *list resources* |
| Azure Export for Terraform (`aztfexport`) | Herramienta de Microsoft que exporta un resource group entero a código |

```hcl
# discover.tfquery.hcl: lista los Key Vaults de un resource group
list "azurerm_key_vault" "todos" {
  provider = azurerm

  config {
    resource_group_name = "rg-security-prod-weu"
  }
}
```

```bash
terraform query -generate-config-out=generated.tf
```

Un buen primer proyecto si vienes de seguridad e identidad: las asignaciones de RBAC y los grupos de Entra. Es lo que más se descontrola cuando se hace a mano y lo que más piden las auditorías.

### Flujo de trabajo para código de aplicación

El libro lo resume en siete pasos que sirven de referencia: control de versiones, ejecutar en local, hacer cambios, enviar a revisión, tests automáticos, merge y release, y despliegue. Las estrategias de despliegue (rolling, blue-green, canary) ya las viste en el capítulo 5. Lo importante es que el mismo artefacto (imagen o versión de módulo) se promociona de dev a stage y de stage a prod.

### Flujo de trabajo para código de infraestructura

Los mismos siete pasos, con diferencias importantes.

**Control de versiones.** Dos repositorios: `modules` (código reutilizable, versionado con tags) y `live` (lo desplegado en cada entorno, que solo referencia versiones de módulos).

> [!IMPORTANT]
> **La regla de oro de Terraform (del libro):** la rama principal del repositorio `live` debe ser un reflejo 1:1 de lo que hay desplegado en producción.

De esa regla salen dos consecuencias:

- Nada de cambios en el portal. Si alguien lo hace, aparecerá como diferencia en el siguiente `plan`. Detecta la deriva con un `terraform plan -detailed-exitcode` programado (código de salida 2 = hay cambios).
- No uses una rama por entorno: las ramas divergen y nadie sabe cuál refleja la realidad. Los entornos van en carpetas (cap. 3).

**Ejecutar en local.** Cada desarrollador prueba en su suscripción sandbox con `terraform apply` y `terraform test` (cap. 9), nunca contra stage ni prod.

**Enviar a revisión.** El PR incluye el código y el `plan`. El revisor mira sobre todo las líneas con `destroy` o *forces replacement*. Acordad una guía de estilo: `terraform fmt`, convención de nombres CAF, etiquetas obligatorias y estructura de carpetas.

**Tests automáticos.** En cada PR: formato, `validate`, TFLint, Checkov o Trivy, `terraform test` y `plan`.

**Merge, release y despliegue.** Tras el merge, el pipeline aplica en stage; para prod, una aprobación manual. Las herramientas típicas: GitHub Actions o Azure DevOps con scripts propios, Atlantis, HCP Terraform y Terragrunt.

### Identidades del pipeline

*Fuentes: SC-300 sesión 11 · SC-500 cap. 04*

Separa el `plan` del `apply` con dos identidades. La de plan solo lee y puede usarla cualquier PR; la de apply escribe, pero su credencial federada solo confía en el entorno `prod` de GitHub, que exige aprobación. Así, un PR malicioso no puede modificar producción.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/ch10-pipeline-dark.svg">
  <img src="img/ch10-pipeline-light.svg" alt="Pipeline: un pull request solo planifica; aplicar en prod exige aprobar el entorno">
</picture>

Cada job pide su token a Entra ID con OIDC; el subject de la credencial federada (`pull_request` o `environment:prod`) decide qué identidad recibe. En GitHub no se guarda ningún secreto.

```hcl
locals {
  repo = "repo:cristianrdgzzz/infra-live"
}

# PLAN: solo lectura, usable desde cualquier pull request
resource "azurerm_user_assigned_identity" "tf_plan" {
  name                = "id-tf-plan-prod"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
}

resource "azurerm_federated_identity_credential" "tf_plan_pr" {
  name                      = "github-pull-request"
  user_assigned_identity_id = azurerm_user_assigned_identity.tf_plan.id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "${local.repo}:pull_request"
}

resource "azurerm_role_assignment" "tf_plan_reader" {
  scope                = "/subscriptions/${var.prod_subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.tf_plan.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "tf_plan_state" {
  scope                = azurerm_storage_container.tfstate.id # el plan toma el lease del state
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.tf_plan.principal_id
  principal_type       = "ServicePrincipal"
}

# APPLY: escribe, pero solo desde el entorno protegido "prod"
resource "azurerm_user_assigned_identity" "tf_apply" {
  name                = "id-tf-apply-prod"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
}

resource "azurerm_federated_identity_credential" "tf_apply_env" {
  name                      = "github-env-prod"
  user_assigned_identity_id = azurerm_user_assigned_identity.tf_apply.id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "${local.repo}:environment:prod"
}

resource "azurerm_role_assignment" "tf_apply_contributor" {
  scope                = "/subscriptions/${var.prod_subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.tf_apply.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "tf_apply_state" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.tf_apply.principal_id
  principal_type       = "ServicePrincipal"
}
```

Si el pipeline también crea asignaciones de RBAC, Contributor no basta. Dale Role Based Access Control Administrator con una condición que limite qué roles puede asignar, nunca Owner. Y si gestiona Entra ID, necesita permisos de Microsoft Graph, que se conceden a la identidad como *app roles* (Apéndice B).

### El pipeline en GitHub Actions

```yaml
# .github/workflows/terraform-prod.yml
name: terraform-prod

on:
  pull_request:
    paths: ["live/prod/**"]
  push:
    branches: [main]
    paths: ["live/prod/**"]

permissions:
  id-token: write      # token OIDC para Entra ID
  contents: read
  pull-requests: write # para comentar el plan en el PR

env:
  ARM_USE_OIDC: "true"
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID_PROD }}
  TF_IN_AUTOMATION: "true"

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    env:
      ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID_PLAN }}
    defaults:
      run:
        working-directory: live/prod/services/web-cluster
    steps:
      - uses: actions/checkout@v7
      - uses: hashicorp/setup-terraform@v4
        with:
          terraform_version: 1.17.0
      - run: terraform fmt -check -recursive
      - run: terraform init -backend-config=../../backend.hcl
      - run: terraform validate
      - run: terraform plan -no-color -out=tfplan

  apply:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: prod # protegido: exige aprobación de revisores
    env:
      ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID_APPLY }}
    defaults:
      run:
        working-directory: live/prod/services/web-cluster
    steps:
      - uses: actions/checkout@v7
      - uses: hashicorp/setup-terraform@v4
        with:
          terraform_version: 1.17.0
      - run: terraform init -backend-config=../../backend.hcl
      - run: terraform apply -auto-approve -no-color
```

El backend `azurerm` lee las mismas variables `ARM_*`, así que con `use_azuread_auth = true` en `backend.hcl` también accede al state sin claves. Ten presente un matiz que el libro discute: este `apply` vuelve a planificar tras el merge, así que lo aplicado puede diferir de lo revisado si alguien cambió algo entretanto. Atlantis y HCP Terraform aplican exactamente el plan revisado.

**En Azure DevOps** el patrón es el mismo: una *service connection* de tipo workload identity federation (que crea la credencial federada por ti), `ARM_USE_OIDC=true` y el ID de la conexión en `ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID`. Al menos una tarea del pipeline debe usar esa service connection para que el agente la cargue.

### El servidor de despliegue

El libro pide que el servidor que aplica cambios esté bloqueado: solo se llega a él por el pipeline y solo él tiene permisos de escritura en prod. En Azure hay un matiz práctico. Si la cuenta del state y el Key Vault tienen el acceso público desactivado (como recomienda mi guía), un runner alojado por GitHub no llega a ellos. Usa runners autoalojados dentro de tu VNet, por ejemplo en un VMSS o en Container Apps jobs, con una managed identity: la variante `use_msi` del cap. 6.

**Errores en el despliegue.** Reintenta los errores transitorios conocidos. Si un `apply` muere a medias, el lease del state puede quedarse puesto: `terraform force-unlock <LOCK_ID>`, solo cuando estés seguro de que no hay otro `apply` en marcha.

**Promoción entre entornos.** El mismo `?ref=v1.4.0` del módulo pasa por dev, stage y prod, en ese orden. Si falla en stage, nunca llega a prod.

### Todo junto

Un cambio típico queda así. Publicas una versión nueva del módulo con su tag y sus tests en verde. Abres un PR en `live` que sube la versión en stage; el pipeline ejecuta análisis estático, tests y `plan` con la identidad de solo lectura. Tras la revisión y el merge, se aplica en stage. Repites el PR para prod, donde el `apply` espera la aprobación del entorno protegido y lo ejecuta la identidad de apply. Todo queda en Git, en los logs del pipeline y en el activity log de Azure.

---

## Apéndice A — Equivalencias AWS (libro) → Azure → Terraform

Tabla para leer el libro con Azure en la cabeza: cada concepto de AWS que aparece en los ejemplos, su equivalente en Azure y el recurso de Terraform que lo crea.

| AWS (libro) | Azure | Recurso Terraform | Cap. |
| --- | --- | --- | --- |
| Cuenta de AWS | Suscripción | `azurerm_subscription` | 1, 7 |
| AWS Organizations (OU) | Management group | `azurerm_management_group` | 1 |
| Región (en el provider) | Región (argumento `location` de cada recurso) | `location` | 7 |
| Usuario IAM | Usuario de Entra ID | `azuread_user` | 5 |
| Grupo IAM | Grupo de Entra ID | `azuread_group`, `azuread_group_member` | 5 |
| Política y rol IAM (permisos) | Rol y asignación de Azure RBAC | `azurerm_role_definition`, `azurerm_role_assignment` | 5 |
| Rol IAM para EC2 (instance profile) | Managed identity | `azurerm_user_assigned_identity`, bloque `identity` | 6 |
| Proveedor OIDC + rol para GitHub | Credencial de identidad federada | `azurerm_federated_identity_credential`, `azuread_application_federated_identity_credential` | 6, 10 |
| VPC | Virtual network | `azurerm_virtual_network` | 2, 4 |
| Subred | Subred | `azurerm_subnet` | 2, 4 |
| Security group | Network security group (+ application security group) | `azurerm_network_security_group`, `azurerm_network_security_rule`, `azurerm_application_security_group` | 2, 4 |
| NAT Gateway | NAT Gateway | `azurerm_nat_gateway` | 2 |
| Instancia EC2 | Máquina virtual | `azurerm_linux_virtual_machine` | 2 |
| AMI | Imagen de marketplace o de Azure Compute Gallery | `source_image_reference`, `azurerm_shared_image_version` | 2 |
| `user_data` | `custom_data` (cloud-init) o `user_data` | argumento de la VM | 2 |
| Launch template + Auto Scaling Group | VM Scale Set + autoescalado | `azurerm_linux_virtual_machine_scale_set`, `azurerm_monitor_autoscale_setting` | 2, 5 |
| Instance refresh | Rolling upgrade del VMSS | `upgrade_mode = "Rolling"` | 5 |
| Application Load Balancer | Application Gateway (capa 7) o Load Balancer (capa 4) | `azurerm_application_gateway`, `azurerm_lb` | 2 |
| Target group + health check | Backend pool + sonda | `azurerm_lb_backend_address_pool`, `azurerm_lb_probe` | 2 |
| Listener y reglas | Regla del load balancer | `azurerm_lb_rule` | 2 |
| Bucket S3 | Storage account + contenedor | `azurerm_storage_account`, `azurerm_storage_container` | 3 |
| Tabla DynamoDB para bloqueos | No hace falta: *lease* del blob | — | 3 |
| RDS (MySQL) | Azure SQL o Azure Database for MySQL Flexible Server | `azurerm_mssql_server`, `azurerm_mysql_flexible_server` | 3 |
| KMS | Claves de Key Vault o Managed HSM | `azurerm_key_vault_key` | 6 |
| Secrets Manager | Secretos de Key Vault | `azurerm_key_vault_secret`, `ephemeral "azurerm_key_vault_secret"` | 6 |
| ACM | Certificados de Key Vault | `azurerm_key_vault_certificate` | 6 |
| EKS | AKS | `azurerm_kubernetes_cluster` | 7 |
| ECR | Azure Container Registry | `azurerm_container_registry` | 7 |
| Route 53 | Azure DNS y Private DNS | `azurerm_dns_zone`, `azurerm_private_dns_zone` | 4 |
| CloudWatch (métricas y alarmas) | Azure Monitor | `azurerm_monitor_metric_alert` | 8 |
| CloudWatch Logs | Log Analytics workspace | `azurerm_log_analytics_workspace` | 8 |
| CloudTrail | Activity log y logs de auditoría de Entra | `azurerm_monitor_diagnostic_setting`, `azurerm_monitor_aad_diagnostic_setting` | 8 |
| AWS Backup | Azure Backup | `azurerm_recovery_services_vault`, `azurerm_backup_policy_vm` | 8 |
| AWS Config / SCP | Azure Policy | `azurerm_policy_definition`, `azurerm_management_group_policy_assignment` | 8 |
| GuardDuty / Security Hub | Microsoft Defender for Cloud | `azurerm_security_center_subscription_pricing` | 8 |

---

## Apéndice B — Identidad (SC-300) en Terraform

Casi todo lo que se configura en Entra ID se puede terraformizar con `azuread`, y lo que no, con `msgraph`. Las excepciones son lo que vive fuera de la nube (la sincronización híbrida) y algunos servicios de seguridad que solo tienen portal.

### Mapa de cobertura

| Sesión de mi guía | Tema | ¿Terraform? | Dónde |
| --- | --- | --- | --- |
| 01 Tenant | Roles integrados y personalizados, unidades administrativas | Sí | Cap. 5: `azuread_directory_role_assignment`, `azuread_custom_directory_role`, `azuread_administrative_unit` |
| 01 Tenant | Dominios, branding, ajustes de usuario y dispositivo | Parcial | `msgraph_resource` contra los endpoints de Graph |
| 02 Identidades | Usuarios, grupos, dinámicos, membresías | Sí | Cap. 5 |
| 02 Identidades | Licencias por grupo | Sí | `azuread_group_license` (abajo) |
| 02 Identidades | Custom security attributes | Parcial | `msgraph_resource` |
| 03 Externos | Invitaciones B2B | Sí | `azuread_invitation` (abajo) |
| 03 Externos | Cross-tenant access settings, sincronización entre tenants | Parcial | `msgraph_resource`; `azuread_synchronization_job` para la sincronización |
| 04 Híbrida | Entra Connect Sync, Cloud Sync, PHS, PTA | No | Se instala y configura en on-premises |
| 06 Autenticación | Authentication strengths | Sí | `azuread_authentication_strength_policy` (cap. 8) |
| 06 Autenticación | Política de métodos (FIDO2, TAP, Authenticator) | Parcial | `msgraph_update_resource` |
| 07 Conditional Access | Políticas y ubicaciones con nombre | Sí | Cap. 8 y `azuread_named_location` (abajo) |
| 08 ID Protection | Políticas basadas en riesgo | Sí, como Conditional Access | `sign_in_risk_levels`, `user_risk_levels` |
| 09 Global Secure Access | Perfiles de tráfico, Private Access | Poco | Portal o Graph |
| 11 Cargas de trabajo | Managed identities, service principals, federación | Sí | Caps. 6 y 10 |
| 12 Aplicaciones | App registrations, enterprise apps, app roles, consentimiento | Sí | Abajo |
| 13 Defender for Cloud Apps | Políticas de sesión, Cloud Discovery | No | Portal de Defender |
| 15 Gobernanza | Entitlement management | Sí | Abajo |
| 15 Gobernanza | Access reviews | Sí, con `msgraph` | Abajo |
| 16 PIM | Roles de Entra, roles de Azure, PIM for Groups | Sí | Cap. 8 y abajo |
| 17 Supervisión | Diagnostic settings de Entra | Sí | Cap. 8: `azurerm_monitor_aad_diagnostic_setting` |

Para gestionar Entra con Terraform, la identidad que lo ejecuta necesita permisos de Microsoft Graph (*app roles* como `User.ReadWrite.All`, `Group.ReadWrite.All` o `Policy.ReadWrite.ConditionalAccess`) o un rol de Entra equivalente. La documentación de cada recurso de `azuread` indica cuáles.

### Usuarios externos y ubicaciones con nombre

*Fuente: SC-300 sesiones 03 y 07*

Una invitación B2B crea un usuario *guest* con UPN `correo#EXT#@tutenant.onmicrosoft.com`. Recuerda: las direcciones de grupo no se pueden invitar, y `UserType` (Guest o Member) no tiene nada que ver con cómo se autentica el usuario. Las ubicaciones con nombre se usan en Conditional Access y mejoran el cálculo de riesgo de ID Protection cuando son de confianza.

```hcl
resource "azuread_invitation" "partner" {
  user_email_address = "ana.garcia@partner.com"
  user_display_name  = "Ana García (Partner)"
  redirect_url       = "https://myapps.microsoft.com"

  message {
    body = "Te damos acceso al portal de proveedores." # body y language son excluyentes
  }
}

resource "azuread_named_location" "oficinas" {
  display_name = "Oficinas corporativas"

  ip {
    ip_ranges = ["203.0.113.0/24", "198.51.100.0/24"]
    trusted   = true
  }
}

resource "azuread_named_location" "paises_bloqueados" {
  display_name = "Países no permitidos"

  country {
    countries_and_regions                 = ["KP", "IR"]
    include_unknown_countries_and_regions = true
  }
}
```

### Aplicaciones: registro, enterprise app, roles y consentimiento

*Fuente: SC-300 sesión 12*

Lo esencial de mi guía, traducido a recursos:

| Concepto | Qué es | Recurso Terraform |
| --- | --- | --- |
| App registration | Definición global de la app en su tenant de origen: credenciales, redirect URIs, permisos que pide y app roles que expone | `azuread_application` |
| Enterprise application | El service principal, la instancia en tu tenant: quién accede ("assignment required"), SSO y consentimientos | `azuread_service_principal` |
| App role | Se define en la app registration y se asigna en la enterprise app | Bloque `app_role` + `azuread_app_role_assignment` |
| Consentimiento de permisos de aplicación | Siempre requiere admin consent | `azuread_app_role_assignment` sobre el service principal de Microsoft Graph |
| Consentimiento de permisos delegados | Lo da el usuario o un admin, según el permiso | `azuread_service_principal_delegated_permission_grant` |

```hcl
data "azuread_client_config" "current" {}

resource "random_uuid" "role_reports_reader" {}

resource "azuread_application" "reports_api" {
  display_name     = "app-reports-api"
  sign_in_audience = "AzureADMyOrg" # single tenant
  owners           = [data.azuread_client_config.current.object_id]

  app_role {
    allowed_member_types = ["User"]
    description          = "Puede leer informes"
    display_name         = "Reports Reader"
    enabled              = true
    id                   = random_uuid.role_reports_reader.result
    value                = "Reports.Reader"
  }
}

resource "azuread_service_principal" "reports_api" {
  client_id                    = azuread_application.reports_api.client_id
  app_role_assignment_required = true # solo usuarios o grupos asignados
  owners                       = [data.azuread_client_config.current.object_id]
}

# El rol se define en la app y se asigna en la enterprise app
resource "azuread_app_role_assignment" "reports_readers" {
  app_role_id         = random_uuid.role_reports_reader.result
  principal_object_id = azuread_group.this["grp-security-team"].object_id
  resource_object_id  = azuread_service_principal.reports_api.object_id
}

# Admin consent de un permiso de APLICACIÓN de Graph para la identidad del pipeline
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azuread_app_role_assignment" "pipeline_group_rw" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Group.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.tf_apply.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
```

Recuerda las trampas de mi guía: borrar la app registration borra también el service principal del tenant de origen; asignar grupos a una app requiere Entra ID P1; y dar consentimiento no da acceso si "assignment required" está activado. Para credenciales de la app, prefiere la federación (`azuread_application_federated_identity_credential`) o un certificado (`azuread_application_certificate`) a un secreto (`azuread_application_password`).

### Licencias por grupo

*Fuente: SC-300 sesión 02*

Desde septiembre de 2024 el portal de Entra ya no asigna licencias (se hace en el centro de administración de Microsoft 365), pero la API sí, y por tanto Terraform también. Los usuarios necesitan `usage_location` antes de recibir una licencia.

```hcl
resource "azuread_group_license" "e5_security" {
  group_object_id = azuread_group.this["grp-security-team"].object_id
  sku_id          = var.m365_e5_sku_id
}
```

### Entitlement management

*Fuente: SC-300 sesión 15*

El modelo de objetos es catálogo → paquete de acceso → política → asignación. Los recursos se añaden primero al catálogo y luego al paquete; la política define quién pide, quién aprueba, cuánto dura y cada cuánto se revisa.

```hcl
resource "azuread_access_package_catalog" "finance" {
  display_name = "Finanzas"
  description  = "Recursos del departamento de finanzas"
}

resource "azuread_access_package_resource_catalog_association" "finance_group" {
  catalog_id             = azuread_access_package_catalog.finance.id
  resource_origin_id     = azuread_group.finance_app_users.object_id
  resource_origin_system = "AadGroup"
}

resource "azuread_access_package" "finance_app" {
  catalog_id   = azuread_access_package_catalog.finance.id
  display_name = "Acceso a la app de finanzas"
  description  = "Membresía del grupo de usuarios de la app de finanzas"
}

resource "azuread_access_package_resource_package_association" "finance_app" {
  access_package_id               = azuread_access_package.finance_app.id
  catalog_resource_association_id = azuread_access_package_resource_catalog_association.finance_group.id
}

resource "azuread_access_package_assignment_policy" "employees" {
  access_package_id = azuread_access_package.finance_app.id
  display_name      = "Empleados con aprobación del manager"
  description       = "90 días, revisión trimestral"
  duration_in_days  = 90

  requestor_settings {
    scope_type = "AllExistingDirectoryMemberUsers"
  }

  approval_settings {
    approval_required = true

    approval_stage {
      approval_timeout_in_days = 14

      primary_approver {
        subject_type = "requestorManager"
      }
    }
  }

  assignment_review_settings {
    enabled                        = true
    review_frequency               = "quarterly"
    duration_in_days               = 14
    review_type                    = "Manager"
    access_review_timeout_behavior = "removeAccess"
  }
}
```

Para el acceso de externos, mi guía recuerda que hacen falta tres cosas a la vez: la organización conectada, el catálogo habilitado para usuarios externos y una política que incluya a usuarios fuera del directorio.

### Access reviews con el provider msgraph

*Fuente: SC-300 sesión 15*

`azuread` no tiene recurso para las access reviews independientes, pero `msgraph_resource` llama a cualquier endpoint de Microsoft Graph con el mismo cuerpo JSON que usarías en la API. Esta revisión trimestral la hacen los propietarios del grupo, aplica el resultado automáticamente y deniega si nadie responde, que es la configuración que recomienda mi guía:

```hcl
resource "msgraph_resource" "review_security_team" {
  url = "identityGovernance/accessReviews/definitions"

  body = {
    displayName          = "Revisión trimestral de grp-security-team"
    descriptionForAdmins = "Revisión de membresía gestionada con Terraform"
    scope = {
      "@odata.type" = "#microsoft.graph.accessReviewQueryScope"
      query         = "/groups/${azuread_group.this["grp-security-team"].object_id}/transitiveMembers"
      queryType     = "MicrosoftGraph"
    }
    reviewers = [
      {
        query     = "/groups/${azuread_group.this["grp-security-team"].object_id}/owners"
        queryType = "MicrosoftGraph"
      }
    ]
    settings = {
      mailNotificationsEnabled        = true
      reminderNotificationsEnabled    = true
      justificationRequiredOnApproval = true
      defaultDecisionEnabled          = true
      defaultDecision                 = "Deny"
      instanceDurationInDays          = 14
      autoApplyDecisionsEnabled       = true
      recommendationsEnabled          = true
      recurrence = {
        pattern = { type = "absoluteMonthly", interval = 3 }
        range   = { type = "noEnd", startDate = "2026-11-02" }
      }
    }
  }
}
```

Requiere Entra ID P2 o ID Governance. El provider `msgraph` aún está en versiones 0.x, así que fija la versión.

### PIM for Groups

*Fuente: SC-300 sesión 16*

Hace *just-in-time* la membresía (o la propiedad) de un grupo. Como un grupo puede tener roles de Entra, roles de Azure y acceso a aplicaciones, una sola activación da todo lo que el grupo controla. Los grupos dinámicos y los sincronizados desde on-premises no se pueden gestionar con PIM.

```hcl
resource "azuread_privileged_access_group_eligibility_schedule" "kv_admins" {
  group_id        = azuread_group.kv_admins.object_id
  principal_id    = azuread_user.this["morpheus"].object_id
  assignment_type = "member"
  duration        = "P90D"
  justification   = "Administración JIT de Key Vault"
}
```

Las reglas de activación del grupo (duración máxima, MFA, aprobación) se definen con `azuread_group_role_management_policy`, con la misma estructura que el `azurerm_role_management_policy` del capítulo 8.

---

## Apéndice C — Seguridad (SC-500) en Terraform

Los bloques A, B y C de mi guía son casi enteramente terraformizables; el bloque D, en parte: Defender for Cloud y Sentinel sí, Security Copilot y la gobernanza de Copilot en Microsoft 365, muy poco. Este apéndice cubre lo que no apareció en los capítulos.

### Mapa de cobertura

| Capítulo de mi guía | Tema | Recurso Terraform | Dónde |
| --- | --- | --- | --- |
| 01 Entra ID | PIM, Conditional Access, managed identities, app registrations | `azuread_*`, `azurerm_pim_*` | Caps. 5, 6, 8 y Apéndice B |
| 02 Key Vault | Vault, RBAC, red, purge protection, claves | `azurerm_key_vault`, `azurerm_key_vault_key` | Cap. 6 |
| 02 Key Vault | Managed HSM | `azurerm_key_vault_managed_hardware_security_module` | — |
| 03 Policy | Definiciones, iniciativas, asignaciones, remediación, locks | `azurerm_policy_*`, `azurerm_management_lock` | Cap. 8 |
| 04 RBAC | Asignaciones, roles personalizados | `azurerm_role_assignment`, `azurerm_role_definition` | Cap. 5 |
| 05 Backup | Soft delete, inmutabilidad, MUA, CRR | `azurerm_recovery_services_vault`, `azurerm_data_protection_resource_guard` | Cap. 8 |
| 06 Storage | Firewall, Entra-only, soft delete, versionado, CMK | `azurerm_storage_account` | Caps. 3 y 6 |
| 06 Storage | Inmutabilidad (WORM) y Defender for Storage por cuenta | `azurerm_storage_container_immutability_policy`, `azurerm_security_center_storage_defender` | Abajo |
| 07 SQL | Entra-only, red, auditoría, TDE con CMK | `azurerm_mssql_*` | Cap. 3 y abajo |
| 08 NSG/ASG/AVNM | NSG, ASG, Virtual Network Manager | `azurerm_network_security_*`, `azurerm_network_manager_*` | Caps. 2, 4, 5 y abajo |
| 08 NSG/ASG/AVNM | VNet flow logs | `azurerm_network_watcher_flow_log` | Cap. 8 |
| 09 Conectividad | Private endpoints, DNS privado, service endpoints | `azurerm_private_endpoint`, `azurerm_private_dns_zone` | Cap. 4 |
| 09 Conectividad | VPN Gateway (S2S y P2S con Entra ID) | `azurerm_virtual_network_gateway`, `azurerm_local_network_gateway` | — |
| 09 Conectividad | Entra Private Access | Portal o Graph | — |
| 10 Firewall | Azure Firewall, políticas, IDPS, threat intelligence | `azurerm_firewall`, `azurerm_firewall_policy*` | Abajo |
| 11 y 12 IA | Azure OpenAI/Foundry, guardrails, Defender for AI | `azurerm_cognitive_account`, `azurerm_cognitive_account_rai_policy` | Abajo |
| 11 IA | Purview DSPM, SharePoint, Copilot Studio | No (Microsoft 365 / Purview) | — |
| 13 VMs | Bastion, Trusted Launch, encryption at host, Machine Configuration | `azurerm_bastion_host`, argumentos de la VM, `azurerm_policy_virtual_machine_configuration_assignment` | Cap. 2 y abajo |
| 13 VMs | JIT VM access | `azapi_resource` (`Microsoft.Security/locations/jitNetworkAccessPolicies`) | — |
| 14 Contenedores | AKS, ACR, Workload ID, Defender for Containers | `azurerm_kubernetes_cluster`, `azurerm_container_registry` | Cap. 7 |
| 15 Apps | App Service, Functions, WAF, API Management | `azurerm_linux_web_app`, `azurerm_web_application_firewall_policy`, `azurerm_api_management` | Abajo |
| 16 Defender for Cloud | Planes, CSPM, contactos | `azurerm_security_center_*` | Cap. 8 |
| 17 Sentinel | Onboarding, reglas, automatización, conectores | `azurerm_sentinel_*` | Abajo |
| 18 Security Copilot | Capacidad (SCU) | `azapi_resource` | El resto, en el portal |

### Azure Firewall

*Fuente: SC-500 cap. 10*

Las claves de mi guía. **SKU:** Basic solo alerta por threat intelligence (no deniega) y no tiene DNS proxy ni FQDN en reglas de red; solo Premium tiene inspección TLS, IDPS y filtrado por URL completa. **Orden fijo de evaluación:** threat intelligence, DNAT, reglas de red, reglas de aplicación, colección de infraestructura y deny implícito. **Despliegue:** subred `AzureFirewallSubnet` de al menos /26 y sin NSG. Y para tráfico web entrante, un WAF; las reglas de aplicación del firewall solo filtran salida.

```hcl
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # nombre obligatorio, mínimo /26, sin NSG
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-afw-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "hub" {
  name                     = "afwp-hub"
  resource_group_name      = azurerm_resource_group.hub.name
  location                 = azurerm_resource_group.hub.location
  sku                      = "Premium"
  threat_intelligence_mode = "Deny"

  intrusion_detection {
    mode = "Deny"
  }

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall" "hub" {
  name                = "afw-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  zones               = ["1", "2", "3"]

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "spokes" {
  name               = "rcg-spokes"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 200

  network_rule_collection {
    name     = "allow-dns"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "dns-to-resolver"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["10.20.0.0/16"]
      destination_addresses = ["10.0.2.4"]
      destination_ports     = ["53"]
    }
  }

  application_rule_collection {
    name     = "allow-updates"
    priority = 200
    action   = "Allow"

    rule {
      name              = "ubuntu-updates"
      source_addresses  = ["10.20.0.0/16"]
      destination_fqdns = ["*.ubuntu.com", "*.canonical.com"]

      protocols {
        type = "Https"
        port = 443
      }

      protocols {
        type = "Http"
        port = 80
      }
    }
  }
}
```

Con la UDR del módulo spoke (cap. 4) apuntando a la IP privada del firewall, toda la salida de los spokes pasa por estas reglas. La jerarquía de políticas (`base_policy_id`) permite que un equipo central imponga una política padre que los equipos de aplicación no pueden saltarse.

### Azure Bastion

*Fuente: SC-500 cap. 13*

RDP y SSH por TLS 443 sin IP pública en las VMs. La subred `AzureBastionSubnet` (mínimo /26) solo necesita 443 de entrada desde Internet: nunca abras 22 ni 3389 en ella. Las funciones avanzadas dependen del SKU (enlaces compartibles y escalado desde Standard; grabación de sesiones y despliegue solo privado en Premium).

```hcl
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # nombre obligatorio, mínimo /26
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/26"]
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bas-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "hub" {
  name                = "bas-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  sku                 = "Standard"
  tunneling_enabled   = true # cliente nativo: az network bastion ssh

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
```

Dos ajustes de VM de ese mismo capítulo de mi guía. **Encryption at host** (`encryption_at_host_enabled = true` en la VM) cifra también disco temporal y cachés; es la recomendación frente a Azure Disk Encryption, que se retira el 15 de septiembre de 2028, y exige registrar la característica en la suscripción. **Machine Configuration** audita o corrige la configuración dentro del sistema operativo con `azurerm_policy_virtual_machine_configuration_assignment`.

### Azure Virtual Network Manager

*Fuente: SC-500 cap. 08*

Las *security admin rules* se evalúan **antes** que los NSG. Una regla `Deny` o `AlwaysAllow` termina la evaluación; una `Allow` deja que los NSG decidan después. La trampa favorita de mi guía: la configuración no hace nada hasta que se **despliega** en una región (`azurerm_network_manager_deployment`).

```hcl
resource "azurerm_network_manager" "corp" {
  name                = "avnm-corp"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  scope_accesses      = ["SecurityAdmin", "Connectivity"]

  scope {
    management_group_ids = [azurerm_management_group.corp.id]
  }
}

resource "azurerm_network_manager_network_group" "all_spokes" {
  name               = "ng-all-spokes"
  network_manager_id = azurerm_network_manager.corp.id
}

resource "azurerm_network_manager_static_member" "app_prod" {
  name                      = "app-prod"
  network_group_id          = azurerm_network_manager_network_group.all_spokes.id
  target_virtual_network_id = module.spoke_prod.vnet_id
}

resource "azurerm_network_manager_security_admin_configuration" "baseline" {
  name               = "sac-baseline"
  network_manager_id = azurerm_network_manager.corp.id
}

resource "azurerm_network_manager_admin_rule_collection" "deny_mgmt" {
  name                            = "arc-deny-mgmt-from-internet"
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.baseline.id
  network_group_ids               = [azurerm_network_manager_network_group.all_spokes.id]
}

resource "azurerm_network_manager_admin_rule" "deny_ssh_rdp" {
  name                     = "deny-ssh-rdp-internet"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.deny_mgmt.id
  action                   = "Deny" # ningún NSG puede saltárselo
  direction                = "Inbound"
  priority                 = 100
  protocol                 = "Tcp"
  destination_port_ranges  = ["22", "3389"]

  source {
    address_prefix_type = "ServiceTag"
    address_prefix      = "Internet"
  }
}

resource "azurerm_network_manager_deployment" "baseline_weu" {
  network_manager_id = azurerm_network_manager.corp.id
  location           = "westeurope"
  scope_access       = "SecurityAdmin"
  configuration_ids  = [azurerm_network_manager_security_admin_configuration.baseline.id]
}
```

### Plataforma de aplicaciones y WAF

*Fuente: SC-500 cap. 15*

Dos pares que mi guía insiste en no confundir. **Private endpoint** protege la entrada a la app; **VNet Integration** gobierna su salida hacia la VNet. **Managed identity** autentica a la app hacia fuera; **Easy Auth** autentica a quien llama a la app. Y las claves de función o de suscripción de APIM no son autenticación real.

```hcl
resource "azurerm_service_plan" "app" {
  name                = "asp-app-prod"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  os_type             = "Linux"
  sku_name            = "P1v3"
}

resource "azurerm_linux_web_app" "app" {
  name                          = "app-tfur-prod-weu"
  resource_group_name           = azurerm_resource_group.app.name
  location                      = azurerm_resource_group.app.location
  service_plan_id               = azurerm_service_plan.app.id
  https_only                    = true
  public_network_access_enabled = false                          # entrada solo por private endpoint
  virtual_network_subnet_id     = azurerm_subnet.app_outbound.id # salida a la VNet

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  key_vault_reference_identity_id = azurerm_user_assigned_identity.app.id

  app_settings = {
    # Referencia a Key Vault: el valor nunca pasa por Terraform
    "DB_PASSWORD" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sql_admin.versionless_id})"
  }

  site_config {
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"
    vnet_route_all_enabled = true
  }

  auth_settings_v2 { # Easy Auth con Entra ID
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "Return401"

    active_directory_v2 {
      client_id            = azuread_application.web.client_id
      tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
    }

    login {
      token_store_enabled = true
    }
  }
}

resource "azurerm_web_application_firewall_policy" "appgw" {
  name                = "wafp-appgw-prod"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  policy_settings {
    enabled = true
    mode    = "Detection" # Detection primero, Prevention después de ajustar
  }

  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
    }
  }
}
```

Este WAF es para Application Gateway (regional). Para protección en el borde frente a bots y DDoS en apps globales, mi guía apunta a Front Door: `azurerm_cdn_frontdoor_firewall_policy`. La app de arriba usa referencias de Key Vault, así que el secreto del capítulo 6 llega a la aplicación sin aparecer en su configuración.

### Storage y SQL: lo que faltaba

*Fuente: SC-500 caps. 06 y 07*

```hcl
# Defender for Storage con ajustes propios para una cuenta concreta
resource "azurerm_security_center_storage_defender" "data" {
  storage_account_id                          = azurerm_storage_account.data.id
  override_subscription_settings_enabled      = true
  malware_scanning_on_upload_enabled          = true
  malware_scanning_on_upload_cap_gb_per_month = 5000
  sensitive_data_discovery_enabled            = true
}

# WORM para evidencias de auditoría
resource "azurerm_storage_container" "evidence" {
  name                  = "evidencias"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

resource "azurerm_storage_container_immutability_policy" "evidence" {
  storage_container_resource_manager_id = azurerm_storage_container.evidence.id
  immutability_period_in_days           = 365
  locked                                = false # true = WORM irreversible
}

# Auditoría y TDE con clave propia en Azure SQL
resource "azurerm_mssql_server_extended_auditing_policy" "app" {
  server_id              = azurerm_mssql_server.app.id
  log_monitoring_enabled = true # envía a Log Analytics vía diagnostic setting
}

resource "azurerm_mssql_server_transparent_data_encryption" "app" {
  server_id             = azurerm_mssql_server.app.id
  key_vault_key_id      = azurerm_key_vault_key.sql_tde.id # vault con purge protection
  auto_rotation_enabled = true
}
```

Recuerda de mi guía: un límite de inmutabilidad solo es WORM de verdad cuando está bloqueado (`locked = true`), y una vez bloqueado no hay vuelta atrás. El TDE con CMK falla si el vault no tiene soft delete y purge protection.

### Microsoft Sentinel

*Fuente: SC-500 cap. 17*

Un Sentinel es un Log Analytics workspace con la solución activada encima. Mi guía recomienda un solo workspace por entorno siempre que se pueda, porque la correlación funciona dentro de un workspace. También separa los roles: Responder gestiona incidentes; Contributor crea reglas, pero no ejecuta playbooks; las automation rules deciden qué se hace con cada incidente.

```hcl
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = azurerm_log_analytics_workspace.security.id
}

resource "azurerm_sentinel_alert_rule_scheduled" "pim_outside_hours" {
  name                       = "pim-activation-outside-hours"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "Activación de PIM fuera de horario"
  severity                   = "Medium"
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  tactics                    = ["PrivilegeEscalation"]

  query = <<-KQL
    AuditLogs
    | where LoggedByService == "PIM"
    | where OperationName has "Add member to role completed"
    | extend hour = datetime_part("hour", TimeGenerated)
    | where hour < 7 or hour > 20
  KQL
}

resource "azurerm_sentinel_automation_rule" "assign_tier1" {
  name                       = "6b9c8f2e-3a1d-4c5e-9f7a-1b2c3d4e5f60" # debe ser un UUID
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "Asignar incidentes nuevos al Tier 1"
  order                      = 1

  action_incident {
    order    = 1
    status   = "Active"
    owner_id = var.tier1_analyst_object_id
  }
}
```

Los conectores de servicio a servicio (por ejemplo `azurerm_sentinel_data_connector_azure_active_directory`) y los basados en el agente AMA con Data Collection Rules (`azurerm_monitor_data_collection_rule`) también se gestionan desde Terraform. Los logs de Entra llegan por el diagnostic setting del capítulo 8.

### IA: Azure OpenAI y Foundry

*Fuente: SC-500 caps. 11 y 12*

Lo que mi guía pide para cargas de IA se traduce en: autenticación solo Entra (sin API keys), red privada, guardrails en cada despliegue de modelo y Defender for AI services.

```hcl
resource "azurerm_cognitive_account" "openai" {
  name                          = "oai-tfur-prod"
  resource_group_name           = azurerm_resource_group.ai.name
  location                      = "swedencentral"
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = "oai-tfur-prod"
  local_auth_enabled            = false # sin API keys: solo Entra ID
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Deny"
  }
}
```

Los guardrails de Foundry son, por debajo, una *RAI policy* de ARM: `azurerm_cognitive_account_rai_policy`, referenciada desde el despliegue del modelo. Defender for AI services se activa como otro plan más (`resource_type = "AI"` en `azurerm_security_center_subscription_pricing`). El AI Gateway de API Management son políticas XML de APIM (`azurerm_api_management_api_policy`). La parte de Microsoft 365 del capítulo 11 (Purview DSPM, SharePoint, Copilot Studio) no se gestiona con Terraform.

---

## Fuentes

**Material propio**

- Yevgeniy Brikman, *Terraform: Up & Running*, 3.ª edición (O'Reilly, 2022): estructura y conceptos.
- *SC-500 Guía de Estudio Completa* (junio de 2026): seguridad en Azure.
- *SC-300 Guía de Estudio Completa*: identidad y gobernanza.

**Documentación de Terraform y providers** (consultada en los repositorios oficiales, octubre de 2026)

- [hashicorp/terraform: changelog de la 1.17](https://github.com/hashicorp/terraform/blob/v1.17/CHANGELOG.md) y versiones anteriores desde la 1.12
- [hashicorp/terraform-provider-azurerm: documentación de recursos](https://github.com/hashicorp/terraform-provider-azurerm/tree/main/website/docs)
- [Guía de actualización a azurerm 5.0](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/website/docs/guides/5.0-upgrade-guide.html.markdown)
- [hashicorp/terraform-provider-azuread: documentación de recursos](https://github.com/hashicorp/terraform-provider-azuread/tree/main/docs)
- [Azure/terraform-provider-azapi](https://github.com/Azure/terraform-provider-azapi)
- [microsoft/terraform-provider-msgraph](https://github.com/microsoft/terraform-provider-msgraph)
- [hashicorp/terraform-provider-random](https://github.com/hashicorp/terraform-provider-random) y [hashicorp/terraform-provider-http](https://github.com/hashicorp/terraform-provider-http)
- [Azure Verified Module de virtual network](https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork)
- [gruntwork-io/terratest](https://github.com/gruntwork-io/terratest)

**Microsoft Learn** (temas de AZ-104 y comprobaciones puntuales)

- [Default outbound access in Azure](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access)
- [What are Azure management groups?](https://learn.microsoft.com/azure/governance/management-groups/overview)
- [Orchestration modes for Virtual Machine Scale Sets](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes)
- [Azure region pairs and nonpaired regions](https://learn.microsoft.com/azure/reliability/regions-paired)
- [Conditional Access authentication strengths](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths)
- [Tutorial: access reviews de grupos de Microsoft 365 con Graph](https://learn.microsoft.com/graph/tutorial-accessreviews-m365group)

---

Hecho por **Cristian Rodríguez** ([github.com/cristianrdgzzz](https://github.com/cristianrdgzzz)) · octubre de 2026
