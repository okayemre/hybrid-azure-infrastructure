resource "azurerm_resource_group" "network" {
  name     = "rg-hybridlab-network-dev"
  location = var.location
}

module "network" {
  source = "./modules/network"

  resource_group_name   = azurerm_resource_group.network.name
  location              = azurerm_resource_group.network.location
  vnet_address_space    = var.vnet_address_space
  gateway_subnet_prefix = var.gateway_subnet_prefix
}
