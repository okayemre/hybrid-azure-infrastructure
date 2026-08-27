output "cluster_id" {
  value       = azurerm_kubernetes_cluster.this.id
  description = "Resource ID of the AKS cluster"
}

output "cluster_name" {
  value       = azurerm_kubernetes_cluster.this.name
  description = "Name of the AKS cluster"
}

output "node_resource_group" {
  value       = azurerm_kubernetes_cluster.this.node_resource_group
  description = "Auto-generated resource group holding the cluster's VM/networking resources (MC_*)"
}

output "kube_config_raw" {
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
  description = "Full kubeconfig for kubectl access — sensitive, never print or commit"
}

output "kube_config" {
  value = {
    host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
    client_certificate     = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
    client_key             = azurerm_kubernetes_cluster.this.kube_config[0].client_key
    cluster_ca_certificate = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  }
  sensitive   = true
  description = "Structured cluster credentials for configuring the helm provider"
}

output "cluster_identity_principal_id" {
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
  description = "Principal ID of the cluster's control-plane managed identity, used to grant access to other Azure resources (e.g. Key Vault)"
}

output "kubelet_identity_object_id" {
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  description = "Object ID of the auto-created kubelet identity, used to grant ACR pull access"
}

output "key_vault_secrets_provider_identity_object_id" {
  value       = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
  description = "Object ID of the managed identity auto-created for the Key Vault Secrets Store CSI driver add-on"
}
