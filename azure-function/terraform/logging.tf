resource "azurerm_log_analytics_workspace" "default" {
  name                = "${local.resource_prefix}-logs"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "logs" {
  name                       = "${local.resource_prefix}-diagnostics"
  target_resource_id         = azurerm_linux_function_app.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.default.id

  enabled_log {
    category = "FunctionAppLogs"
  }
}

resource "azurerm_log_analytics_workspace" "insights" {
  name                = "${local.resource_prefix}-insights"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 365
  tags                = local.tags
}
