output "azurerm_resource_group" {
  value       = local.existing_resource_group == "" ? azurerm_resource_group.default[0].id : null
  description = "Default Azure Resource Group"
}

output "azurerm_log_analytics_workspace" {
  value       = length(local.function_apps) > 0 ? azurerm_log_analytics_workspace.default[0].id : null
  description = "Function App Log Analytics Workspace"
}

output "azurerm_windows_function_app" {
  value       = { for fn in azurerm_windows_function_app.app : fn.name => fn.default_hostname }
  description = "Windows Function App Hostnames"
}