resource "azurerm_key_vault" "function_app" {
  name                       = "${local.resource_prefix}-kv"
  location                   = local.azure_location
  resource_group_name        = local.resource_group.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  enable_rbac_authorization  = false
  purge_protection_enabled   = true

  dynamic "access_policy" {
    for_each = data.azuread_user.key_vault_access

    content {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = access_policy.value["object_id"]

      secret_permissions = [
        "Set",
        "Get",
        "Delete",
        "Purge",
        "Recover",
        "List",
      ]
    }
  }

  dynamic "access_policy" {
    for_each = local.function_app_names

    content {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = azurerm_user_assigned_identity.default[access_policy.value].principal_id

      secret_permissions = [
        "Get",
      ]
    }
  }

  network_acls {
    bypass                     = "None"
    default_action             = "Deny"
    ip_rules                   = length(local.key_vault_access_ipv4) > 0 ? local.key_vault_access_ipv4 : null
    virtual_network_subnet_ids = []
  }

  tags = local.tags
}

resource "azurerm_key_vault_secret" "secret_app_setting" {
  for_each = { for i, s in local.function_apps_secrets : s.key => s.value }

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.function_app.id
}
