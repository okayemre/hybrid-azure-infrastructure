output "cluster_id" {
  value       = module.aks.cluster_id
  description = "Resource ID of the AKS cluster, for downstream diagnostic settings wiring"
}

output "cluster_identity_principal_id" {
  value       = module.aks.cluster_identity_principal_id
  description = "Principal ID of the cluster's control-plane managed identity, for downstream role assignments"
}

output "kubelet_identity_object_id" {
  value       = module.aks.kubelet_identity_object_id
  description = "Object ID of the kubelet identity, for downstream ACR role assignments"
}

output "key_vault_secrets_provider_identity_object_id" {
  value       = module.aks.key_vault_secrets_provider_identity_object_id
  description = "Object ID of the CSI driver's managed identity, for downstream Key Vault role assignment"
}
