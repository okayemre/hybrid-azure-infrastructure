variable "name" {
  type        = string
  description = "Globally unique name for the Container Registry (alphanumeric only, no hyphens)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the Container Registry will be created"
}

variable "location" {
  type        = string
  description = "Azure region for the Container Registry"
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "Pricing tier for the Container Registry"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the Container Registry"
}
