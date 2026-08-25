variable "location" {
  type        = string
  description = "Azure region for the network resources"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Address space for the network VNet"
}

variable "gateway_subnet_prefix" {
  type        = string
  description = "CIDR prefix for the GatewaySubnet"
}

variable "subnets" {
  type = map(object({
    address_prefix = string
  }))
  description = "Functional subnets (ingress, workload, platform) passed through to the network module"
}
