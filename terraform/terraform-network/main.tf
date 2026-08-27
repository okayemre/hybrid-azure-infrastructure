locals {
  common_tags = {
    project     = "hybridlab"
    environment = "dev"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "network" {
  name     = "rg-hybridlab-network-dev"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "./modules/network"

  resource_group_name   = azurerm_resource_group.network.name
  location              = azurerm_resource_group.network.location
  vnet_address_space    = var.vnet_address_space
  gateway_subnet_prefix = var.gateway_subnet_prefix
  subnets               = var.subnets
  tags                  = local.common_tags
}

resource "azurerm_resource_group" "workload" {
  name     = "rg-hybridlab-workload-dev"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-hybridlab-platform-dev"
  location = var.location
  tags     = local.common_tags
}
