output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "ID of the hybridlab virtual network"
}

output "subnet_ids" {
  value       = { for k, s in azurerm_subnet.functional : k => s.id }
  description = "Map of functional subnet name to subnet ID (ingress, workload, platform)"
}

output "nsg_ids" {
  value       = { for k, n in azurerm_network_security_group.functional : k => n.id }
  description = "Map of functional subnet name to its associated NSG ID"
}
