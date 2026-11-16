# Estado remoto en el Storage de la raíz platform. El estado de AzureGoat
# contiene claves del laboratorio (Cosmos DB, Storage): nunca en local ni en git.
#   terraform init -backend-config="storage_account_name=<nombre>"
terraform {
  backend "azurerm" {
    resource_group_name = "rg-platform"
    container_name      = "tfstate"
    key                 = "azuregoat.tfstate"
    use_azuread_auth    = true
  }
}
