output "id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "Resource ID of the Log Analytics Workspace"
}

output "workspace_id" {
  value       = azurerm_log_analytics_workspace.this.workspace_id
  description = "Workspace (customer) ID, used by agents/extensions to report data"
}
