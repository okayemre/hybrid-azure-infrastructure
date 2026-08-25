resource "azurerm_virtual_network" "this" {
  name                = "vnet-hybridlab-dev"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

resource "azurerm_subnet" "functional" {
  for_each             = var.subnets
  name                 = "snet-${each.key}-dev"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.address_prefix]
}

resource "azurerm_network_security_group" "functional" {
  for_each            = var.subnets
  name                = "nsg-${each.key}-dev"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "functional" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.functional[each.key].id
  network_security_group_id = azurerm_network_security_group.functional[each.key].id
}
