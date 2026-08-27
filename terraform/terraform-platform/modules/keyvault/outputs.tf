output "id" {
  value       = azurerm_key_vault.this.id
  description = "Resource ID of the Key Vault"
}

output "name" {
  value       = azurerm_key_vault.this.name
  description = "Name of the Key Vault"
}

output "uri" {
  value       = azurerm_key_vault.this.vault_uri
  description = "URI used to address secrets, keys, and certificates in this Key Vault"
}


