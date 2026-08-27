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

variable "workload_state_resource_group_name" {
  type        = string
  description = "Resource group holding the workload root's remote state"
}

variable "workload_state_storage_account_name" {
  type        = string
  description = "Storage account holding the workload root's remote state"
}

variable "workload_state_container_name" {
  type        = string
  description = "Blob container holding the workload root's remote state"
}

variable "workload_state_key" {
  type        = string
  description = "Blob key for the workload root's state file"
}

variable "alert_email" {
  type        = string
  description = "Email address that receives Azure Monitor alert notifications"
}
