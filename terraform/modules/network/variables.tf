
variable "resource_group_name" {
  type        = string
  description = "Resource group where the network resources will be created"
}

variable "location" {
  type        = string
  description = "Azure region for the network resources"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Address space for the virtual network"
}

variable "gateway_subnet_prefix" {
  type        = string
  description = "CIDR prefix for the GatewaySubnet"
}
