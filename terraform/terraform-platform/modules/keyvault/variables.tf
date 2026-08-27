variable "name" {
  type        = string
  description = "Globally unique name for the Key Vault"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the Key Vault will be created"
}

variable "location" {
  type        = string
  description = "Azure region for the Key Vault"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID used for the Key Vault"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the Key Vault"
}
