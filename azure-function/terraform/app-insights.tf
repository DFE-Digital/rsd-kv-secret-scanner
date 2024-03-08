resource "azurerm_application_insights" "default" {
  name                = "${local.resource_prefix}-insights"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.insights.id
  retention_in_days   = 365
  tags                = local.tags
}
