terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13"
    }
  }

  # Estado en el Storage de la raíz platform:
  #   terraform init -backend-config="storage_account_name=<nombre>"
  backend "azurerm" {
    resource_group_name = "rg-platform"
    container_name      = "tfstate"
    key                 = "vampi.tfstate"
    use_azuread_auth    = true
  }
}

provider "azurerm" {
  features {}
  # Los proveedores de recursos (Microsoft.App, Microsoft.OperationalInsights)
  # los registra la raíz platform.
}
