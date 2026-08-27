output "id" {
  value       = azurerm_container_registry.this.id
  description = "Resource ID of the Container Registry"
}

output "name" {
  value       = azurerm_container_registry.this.name
  description = "Name of the Container Registry"
}

output "login_server" {
  value       = azurerm_container_registry.this.login_server
  description = "Login server hostname used to push/pull images (e.g. for docker login and image tags)"
}
