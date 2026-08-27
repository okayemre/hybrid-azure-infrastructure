output "key_vault_uri" {
  value       = module.keyvault.uri
  description = "URI of the Key Vault, for referencing in application configuration"
}

output "acr_login_server" {
  value       = module.acr.login_server
  description = "Login server hostname of the Container Registry, for image tags and docker login"
}

output "log_analytics_workspace_id" {
  value       = module.log_analytics.id
  description = "Resource ID of the Log Analytics Workspace, for downstream diagnostic settings wiring"
}

output "key_vault_secret_name" {
  value       = azurerm_key_vault_secret.demo.name
  description = "Name of the demo secret stored in Key Vault, referenced by the SecretProviderClass manifest"
}

output "github_actions_client_id" {
  value       = azuread_application.github_actions.client_id
  description = "Client ID of the GitHub Actions App Registration, used for OIDC login in the CI/CD workflow"
}

output "github_actions_tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure AD tenant ID, used for OIDC login in the CI/CD workflow"
}

output "azure_subscription_id" {
  value       = data.azurerm_client_config.current.subscription_id
  description = "Azure subscription ID, used for OIDC login in the CI/CD workflow"
}
