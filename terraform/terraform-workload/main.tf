data "terraform_remote_state" "network" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.network_state_resource_group_name
    storage_account_name = var.network_state_storage_account_name
    container_name       = var.network_state_container_name
    key                  = var.network_state_key
  }
}

data "azurerm_resource_group" "workload" {
  name = data.terraform_remote_state.network.outputs.resource_group_names["workload"]
}

locals {
  common_tags = {
    project     = "hybridlab"
    environment = "dev"
    managed_by  = "terraform"
  }
}

module "aks" {
  source = "./modules/aks"

  resource_group_name        = data.azurerm_resource_group.workload.name
  location                   = data.azurerm_resource_group.workload.location
  subnet_id                  = data.terraform_remote_state.network.outputs.network_subnet_ids["workload"]
  log_analytics_workspace_id = data.terraform_remote_state.platform.outputs.log_analytics_workspace_id
  tags                       = local.common_tags
}

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
}

data "terraform_remote_state" "platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.platform_state_resource_group_name
    storage_account_name = var.platform_state_storage_account_name
    container_name       = var.platform_state_container_name
    key                  = var.platform_state_key
  }
}
