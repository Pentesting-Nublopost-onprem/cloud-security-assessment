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

  # Solo los jobs de este repositorio que declaren el environment obtienen el token.
  github_subject = "repo:${var.github_org}/${var.github_repo}:environment:${var.github_environment}"

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

  # Endpoint público: los runners de GitHub no tienen IP fija. El acceso exige
  # identidad y rol de datos. TO-BE: endpoint privado y runner propio.
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

# ── Identidad de despliegue para GitHub Actions (OIDC) ────────

resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-github-deploy"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tags                = local.tags
}

# Sin secretos en GitHub: Entra ID acepta el token OIDC del workflow si el
# subject coincide exactamente con este repositorio y environment.
resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-${var.github_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = local.github_subject
}

resource "azurerm_role_assignment" "deploy_state" {
  scope                            = azurerm_storage_container.tfstate.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.deploy.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "GitHub Actions: estado de Terraform"
}

resource "azurerm_role_assignment" "deploy_vampi" {
  scope                            = azurerm_resource_group.vampi.id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_user_assigned_identity.deploy.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "GitHub Actions: despliegue de VAmPI"
}

# AzureGoat crea asignaciones de roles, así que necesita Owner, limitado a su grupo.
resource "azurerm_role_assignment" "deploy_azuregoat" {
  scope                            = azurerm_resource_group.azuregoat.id
  role_definition_name             = "Owner"
  principal_id                     = azurerm_user_assigned_identity.deploy.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "GitHub Actions: despliegue de AzureGoat (riesgo aceptado, solo este grupo)"
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
