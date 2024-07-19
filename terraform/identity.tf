resource "azurerm_user_assigned_identity" "default" {
  location            = azurerm_resource_group.default.location
  name                = "${local.resource_prefix}-uami-containerjob"
  resource_group_name = azurerm_resource_group.default.name

  tags = local.tags
}
