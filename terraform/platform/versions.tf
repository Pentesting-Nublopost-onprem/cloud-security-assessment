terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13"
    }
  }
}

provider "azurerm" {
  features {}

  # El Storage del estado no acepta claves compartidas: Terraform usa Entra ID.
  storage_use_azuread = true

  # azurerm 5.x no registra proveedores de recursos por defecto. Esta raíz, que
  # ejecuta el operador con permisos sobre la suscripción, registra los que usan
  # todas las pilas del laboratorio. Así la identidad de despliegue, que solo
  # tiene permisos por grupo de recursos, no necesita hacerlo.
  resource_providers_to_register = [
    "Microsoft.App",
    "Microsoft.Automation",
    "Microsoft.Compute",
    "Microsoft.Consumption",
    "Microsoft.DocumentDB",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.Storage",
    "Microsoft.Web",
  ]
}
