output "state_storage_account" {
  description = "Storage del estado: se pasa a terraform init en las demás raíces."
  value       = azurerm_storage_account.state.name
}
