variable "resource_group_name" {
  type        = string
  description = "Resource group where the AKS cluster will be created"
}

variable "location" {
  type        = string
  description = "Azure region for the AKS cluster"
}

variable "subnet_id" {
  type        = string
  description = "ID of the workload subnet the AKS nodes will attach to"
}

variable "node_vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "VM size for the default (system) node pool"
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Number of nodes in the default (system) node pool"
}

variable "pod_cidr" {
  type        = string
  default     = "10.244.0.0/16"
  description = "CIDR range for pod IPs (Azure CNI Overlay) — must not overlap the VNet address space"
}

variable "service_cidr" {
  type        = string
  default     = "10.245.0.0/16"
  description = "CIDR range for Kubernetes service IPs — must not overlap the VNet or pod CIDR"
}

variable "dns_service_ip" {
  type        = string
  default     = "10.245.0.10"
  description = "IP address within service_cidr reserved for cluster DNS"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics Workspace for Container Insights (oms_agent)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the AKS cluster"
}
