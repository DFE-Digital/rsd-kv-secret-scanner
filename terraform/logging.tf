resource "azurerm_log_analytics_workspace" "default" {
  name                = "${local.resource_prefix}-logs"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}
