data "azurerm_subscription" "current" {}

data "azurerm_key_vault" "target_resource" {
  for_each = local.key_vault_targets

  name                = each.value["name"]
  resource_group_name = each.value["resource_group_name"]
}

data "azurerm_managed_api" "container_instance_group" {
  name     = "aci"
  location = azurerm_resource_group.default.location
}
