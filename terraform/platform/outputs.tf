output "state_storage_account" {
  description = "Storage del estado: se pasa a terraform init en las demás raíces."
  value       = azurerm_storage_account.state.name
}

output "deploy_identity_client_id" {
  description = "AZURE_CLIENT_ID para GitHub Actions (variable del environment, no es un secreto)."
  value       = azurerm_user_assigned_identity.deploy.client_id
}

output "tenant_id" {
  description = "AZURE_TENANT_ID para GitHub Actions."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "AZURE_SUBSCRIPTION_ID para GitHub Actions."
  value       = data.azurerm_subscription.current.subscription_id
}

output "github_oidc_subject" {
  description = "Subject que debe presentar el token OIDC del workflow."
  value       = local.github_subject
}
