resource "azurerm_user_assigned_identity" "default" {
  for_each = local.function_app_names

  location            = local.resource_group.location
  name                = "${local.environment}${each.key}-uami"
  resource_group_name = local.resource_group.name
  tags                = local.tags
}
