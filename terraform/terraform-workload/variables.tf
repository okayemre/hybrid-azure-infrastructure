variable "network_state_resource_group_name" {
  type        = string
  description = "Resource group holding the network root's remote state"
}

variable "network_state_storage_account_name" {
  type        = string
  description = "Storage account holding the network root's remote state"
}

variable "network_state_container_name" {
  type        = string
  description = "Blob container holding the network root's remote state"
}

variable "network_state_key" {
  type        = string
  description = "Blob key for the network root's state file"
}

variable "platform_state_resource_group_name" {
  type        = string
  description = "Resource group containing the platform layer's Terraform state storage account"
}

variable "platform_state_storage_account_name" {
  type        = string
  description = "Storage account holding the platform layer's remote state"
}

variable "platform_state_container_name" {
  type        = string
  description = "Blob container holding the platform layer's remote state"
}

variable "platform_state_key" {
  type        = string
  description = "Blob key (filename) of the platform layer's state file"
}
