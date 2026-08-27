data "terraform_remote_state" "network" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.network_state_resource_group_name
    storage_account_name = var.network_state_storage_account_name
    container_name       = var.network_state_container_name
    key                  = var.network_state_key
  }
}

data "terraform_remote_state" "workload" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.workload_state_resource_group_name
    storage_account_name = var.workload_state_storage_account_name
    container_name       = var.workload_state_container_name
    key                  = var.workload_state_key
  }
}

data "azurerm_resource_group" "platform" {
  name = data.terraform_remote_state.network.outputs.resource_group_names["platform"]
}

locals {
  common_tags = {
    project     = "hybridlab"
    environment = "dev"
    managed_by  = "terraform"
  }
}

resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

data "azurerm_client_config" "current" {}

module "keyvault" {
  source = "./modules/keyvault"

  name                = "kv-hybridlab-dev-${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = data.azurerm_resource_group.platform.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags
}

module "acr" {
  source = "./modules/acr"

  name                = "acrhybridlabdev${random_string.suffix.result}"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = data.azurerm_resource_group.platform.location
  tags                = local.common_tags
}

module "log_analytics" {
  source = "./modules/log_analytics"

  name                = "log-hybridlab-dev"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = data.azurerm_resource_group.platform.location
  tags                = local.common_tags
}

resource "azurerm_monitor_data_collection_endpoint" "aks" {
  name                = "dce-aks-hybridlab-dev"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = data.azurerm_resource_group.platform.location
  kind                = "Linux"
  tags                = local.common_tags
}

resource "azurerm_monitor_data_collection_rule" "aks" {
  name                        = "dcr-aks-hybridlab-dev"
  resource_group_name         = data.azurerm_resource_group.platform.name
  location                    = data.azurerm_resource_group.platform.location
  kind                        = "Linux"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks.id

  destinations {
    log_analytics {
      workspace_resource_id = module.log_analytics.id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams = [
      "Microsoft-ContainerLogV2",
      "Microsoft-KubeEvents",
      "Microsoft-KubePodInventory",
      "Microsoft-InsightsMetrics",
      "Microsoft-ContainerInventory",
      "Microsoft-ContainerNodeInventory",
      "Microsoft-KubeNodeInventory",
      "Microsoft-KubeServices",
      "Microsoft-KubePVInventory",
    ]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      extension_name = "ContainerInsights"
      name           = "ContainerInsightsExtension"
      streams = [
        "Microsoft-ContainerLogV2",
        "Microsoft-KubeEvents",
        "Microsoft-KubePodInventory",
        "Microsoft-InsightsMetrics",
        "Microsoft-ContainerInventory",
        "Microsoft-ContainerNodeInventory",
        "Microsoft-KubeNodeInventory",
        "Microsoft-KubeServices",
        "Microsoft-KubePVInventory",
      ]
      extension_json = jsonencode({
        dataCollectionSettings = {
          enableContainerLogV2   = true
          interval               = "1m"
          namespaceFilteringMode = "Off"
        }
      })
    }
  }

  description = "Data Collection Rule for AKS Container Insights"
  tags        = local.common_tags
}

resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = "dcra-aks-hybridlab-dev"
  target_resource_id      = data.terraform_remote_state.workload.outputs.cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks.id
}

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-hybridlab-dev"
  resource_group_name = data.azurerm_resource_group.platform.name
  short_name          = "hybridlab"

  email_receiver {
    name                    = "primary-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "aks_node_cpu" {
  name                = "alert-aks-node-cpu-dev"
  resource_group_name = data.azurerm_resource_group.platform.name
  scopes              = [data.terraform_remote_state.workload.outputs.cluster_id]
  description         = "Fires when average node CPU usage exceeds 80% for 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pod_failures" {
  name                    = "alert-aks-pod-failures-dev"
  resource_group_name     = data.azurerm_resource_group.platform.name
  location                = data.azurerm_resource_group.platform.location
  scopes                  = [module.log_analytics.id]
  severity                = 2
  evaluation_frequency    = "PT5M"
  window_duration         = "PT5M"
  auto_mitigation_enabled = true

  criteria {
    query                   = <<-QUERY
      KubePodInventory
      | where ContainerStatus in ("CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull")
      | summarize count() by ContainerStatus, Name
    QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }

  description  = "Fires when a pod enters CrashLoopBackOff, ImagePullBackOff, or ErrImagePull"
  display_name = "AKS Pod Failure Detection"
  tags         = local.common_tags
}

resource "random_uuid" "workbook_aks_monitoring" {}

resource "azurerm_application_insights_workbook" "aks_monitoring" {
  name                = random_uuid.workbook_aks_monitoring.result
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = data.azurerm_resource_group.platform.location
  display_name        = "AKS Monitoring - hybridlab-dev"
  source_id           = lower(module.log_analytics.id)
  category            = "workbook"

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "## AKS Monitoring — Milestone H\n\nContainer Insights overview for `aks-hybridlab-dev`. Pod health and node status, sourced from Log Analytics."
        }
        name = "title"
      },
      {
        type = 3
        content = {
          version                 = "KqlItem/1.0"
          query                   = "KubePodInventory\n| summarize count() by ContainerStatus\n| render piechart"
          size                    = 0
          title                   = "Pod status distribution"
          queryType               = 0
          resourceType            = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [module.log_analytics.id]
        }
        name = "pod-status"
      },
      {
        type = 3
        content = {
          version                 = "KqlItem/1.0"
          query                   = "KubeNodeInventory\n| summarize arg_max(TimeGenerated, *) by Computer\n| project Computer, Status, KubeletVersion, TimeGenerated"
          size                    = 0
          title                   = "Node status"
          queryType               = 0
          resourceType            = "microsoft.operationalinsights/workspaces"
          crossComponentResources = [module.log_analytics.id]
        }
        name = "node-status"
      }
    ]
    isLocked            = false
    fallbackResourceIds = [module.log_analytics.id]
  })

  tags = local.common_tags
}

resource "azurerm_role_assignment" "aks_keyvault_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.workload.outputs.kubelet_identity_object_id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.terraform_remote_state.workload.outputs.kubelet_identity_object_id
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks-hybridlab-dev"
  target_resource_id         = data.terraform_remote_state.workload.outputs.cluster_id
  log_analytics_workspace_id = module.log_analytics.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
resource "azurerm_key_vault_secret" "demo" {
  name         = "demo-secret"
  value        = "hello-from-key-vault"
  key_vault_id = module.keyvault.id

  depends_on = [azurerm_role_assignment.terraform_keyvault_secrets_officer]
}

resource "azurerm_role_assignment" "terraform_keyvault_secrets_officer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "policy-allowed-locations-dev"
  resource_group_id    = data.azurerm_resource_group.platform.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  display_name         = "Allowed locations - hybridlab platform RG"
  description          = "Restricts new resource creation in this resource group to Sweden Central only"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = ["swedencentral"]
    }
  })
}

data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag on resources"
}

resource "azurerm_resource_group_policy_assignment" "require_project_tag" {
  name                 = "policy-require-project-tag-dev"
  resource_group_id    = data.azurerm_resource_group.platform.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  display_name         = "Require 'project' tag - hybridlab platform RG"
  description          = "Denies creation of resources in this resource group that are missing the 'project' tag"

  parameters = jsonencode({
    tagName = {
      value = "project"
    }
  })
}

resource "azuread_application" "github_actions" {
  display_name = "hybridlab-github-actions-dev"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-main-branch"
  description    = "Allows GitHub Actions workflows on the main branch to authenticate via OIDC, without a stored secret"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:okayemre/hybrid-azure-infrastructure:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "github_main_immutable" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-main-branch-immutable-id"
  description    = "Matches GitHub's newer immutable-ID OIDC subject format (numeric org/repo IDs), in effect for repos created after July 2026"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:okayemre@107372052/hybrid-azure-infrastructure@1345423705:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_aks_admin" {
  scope                = data.terraform_remote_state.workload.outputs.cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = azuread_service_principal.github_actions.object_id
}

data "azurerm_subscription" "current" {}

resource "azurerm_consumption_budget_subscription" "hybridlab" {
  name            = "budget-hybridlab-dev"
  subscription_id = data.azurerm_subscription.current.id
  amount          = 20
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-08-01T00:00:00Z"
    end_date   = "2027-08-01T00:00:00Z"
  }

  filter {
    tag {
      name   = "project"
      values = ["hybridlab"]
    }
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}
