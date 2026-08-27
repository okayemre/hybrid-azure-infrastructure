variable "name" {
  type        = string
  description = "Name of the Log Analytics Workspace"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the Log Analytics Workspace will be created"
}

variable "location" {
  type        = string
  description = "Azure region for the Log Analytics Workspace"
}

variable "sku" {
  type        = string
  default     = "PerGB2018"
  description = "Pricing tier for the Log Analytics Workspace"
}

variable "retention_in_days" {
  type        = number
  default     = 30
  description = "Number of days to retain ingested data"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the Log Analytics Workspace"
}
