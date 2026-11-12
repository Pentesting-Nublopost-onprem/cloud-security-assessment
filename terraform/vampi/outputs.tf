output "vampi_url" {
  description = "URL de VAmPI (solo responde a allowed_ip)."
  value       = "https://${azurerm_container_app.vampi.ingress[0].fqdn}"
}

output "vampi_outbound_ips" {
  description = "IPs de salida de Container Apps (para el análisis de red)."
  value       = azurerm_container_app.vampi.outbound_ip_addresses
}
