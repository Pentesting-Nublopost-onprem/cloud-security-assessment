data "azurerm_resource_group" "vampi" {
  name = "rg-vampi"
}

locals {
  tags = {
    project     = "cloud-security-assessment"
    environment = "lab"
    managed_by  = "terraform"
    component   = "vampi"
  }
}

# Registros de la aplicación para la fase de defensa. Cuota diaria como tope de coste.
resource "azurerm_log_analytics_workspace" "vampi" {
  name                = "log-vampi"
  resource_group_name = data.azurerm_resource_group.vampi.name
  location            = data.azurerm_resource_group.vampi.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.5
  tags                = local.tags
}

resource "azurerm_container_app_environment" "vampi" {
  name                       = "cae-vampi"
  resource_group_name        = data.azurerm_resource_group.vampi.name
  location                   = data.azurerm_resource_group.vampi.location
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.vampi.id
  tags                       = local.tags
}

resource "azurerm_container_app" "vampi" {
  name                         = "ca-vampi"
  container_app_environment_id = azurerm_container_app_environment.vampi.id
  resource_group_name          = data.azurerm_resource_group.vampi.name
  revision_mode                = "Single"

  template {
    # Escala a cero: sin coste en reposo. La base de datos de VAmPI vive dentro
    # del contenedor y se pierde al escalar: se reinicia con GET /createdb.
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "vampi"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "vulnerable"
        value = tostring(var.vulnerable)
      }
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 5000
    transport                  = "auto"
    allow_insecure_connections = false # HTTP se redirige a HTTPS

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }

    # Lista de permitidos: cualquier otra IP recibe 403.
    ip_security_restriction {
      name             = "auditor"
      description      = "IP publica del auditor (portatil y VM on-prem)"
      action           = "Allow"
      ip_address_range = "${var.allowed_ip}/32"
    }
  }

  tags = local.tags
}
