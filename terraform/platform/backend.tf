# Estado remoto en el Storage que crea esta misma raíz. La primera vez,
# bootstrap.sh aplica con estado local y después lo migra aquí.
# El nombre del Storage se pasa al iniciar:
#   terraform init -backend-config="storage_account_name=<nombre>"
terraform {
  backend "azurerm" {
    resource_group_name = "rg-platform"
    container_name      = "tfstate"
    key                 = "platform.tfstate"
    use_azuread_auth    = true
  }
}
