data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

locals {
  tags = {
    project     = "cloud-security-assessment"
    environment = "lab"
    managed_by  = "terraform"
  }

  # Nombre estable y único por suscripción (3-24 caracteres, minúsculas y números).
  state_storage_name = "tfstate${substr(sha1(data.azurerm_subscription.current.subscription_id), 0, 10)}"

  # Azure exige que el presupuesto empiece el día 1 del mes en curso o de uno futuro.
  budget_start = coalesce(var.budget_start_date, formatdate("YYYY-MM-01'T'00:00:00'Z'", plantimestamp()))
}

# ── Grupos de recursos ────────────────────────────────────────

resource "azurerm_resource_group" "platform" {
  name     = "rg-platform"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "vampi" {
  name     = "rg-vampi"
  location = var.location
  tags     = local.tags
}

# AzureGoat espera este grupo ya creado (no lo crea su Terraform).
resource "azurerm_resource_group" "azuregoat" {
  name     = "azuregoat_app"
  location = var.azuregoat_location
  tags     = local.tags
}

# ── Estado de Terraform ───────────────────────────────────────

resource "azurerm_storage_account" "state" {
  name                             = local.state_storage_name
  resource_group_name              = azurerm_resource_group.platform.name
  location                         = azurerm_resource_group.platform.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false

  # Solo Entra ID + RBAC: no hay claves de acceso que filtrar.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  # Endpoint público: Cloud Shell no tiene IP fija. El acceso exige identidad
  # y rol de datos. TO-BE: endpoint privado.
  public_network_access = "Enabled"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Quien ejecuta Terraform a mano (el operador) necesita acceso de datos al estado.
resource "azurerm_role_assignment" "state_operator" {
  scope                = azurerm_storage_container.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  description          = "Operador del laboratorio: lectura y escritura del estado de Terraform"
}

# ── Presupuesto ───────────────────────────────────────────────
# Avisa por correo; no detiene el gasto. Al acabar cada sesión: terraform destroy.

resource "azurerm_consumption_budget_subscription" "lab" {
  count = var.create_budget ? 1 : 0

  name            = "budget-cloud-security-lab"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = local.budget_start
  }

  # La fecha se calcula en cada plan; una vez creado, el presupuesto no se toca.
  lifecycle {
    ignore_changes = [time_period]
  }

  notification {
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}
