output "network_subnet_ids" {
  value       = module.network.subnet_ids
  description = "Functional subnet IDs from the network module, for downstream workload/platform wiring"
}

output "resource_group_names" {
  value = {
    network  = azurerm_resource_group.network.name
    workload = azurerm_resource_group.workload.name
    platform = azurerm_resource_group.platform.name
  }
  description = "Names of the top-level resource groups, for downstream roots to reference"

}
