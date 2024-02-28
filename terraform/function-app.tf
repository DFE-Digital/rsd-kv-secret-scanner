resource "azurerm_service_plan" "default" {
  count = length(local.function_apps) > 0 ? 1 : 0

  name                = "${local.resource_prefix}-serviceplan"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  os_type             = local.service_plan_os
  sku_name            = local.service_plan_sku

  tags = local.tags
}

resource "azurerm_windows_function_app" "app" {
  for_each = local.function_apps

  name                = "${local.environment}${each.key}"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location

  storage_account_name       = azurerm_storage_account.default[0].name
  storage_account_access_key = azurerm_storage_account.default[0].primary_access_key
  service_plan_id            = azurerm_service_plan.default[0].id

  ftp_publish_basic_authentication_enabled       = lookup(each.value, "ftp_publish_basic_authentication_enabled", false)
  webdeploy_publish_basic_authentication_enabled = lookup(each.value, "webdeploy_publish_basic_authentication_enabled", true)

  https_only = true

  app_settings = each.value.app_settings

  site_config {
    always_on                              = true
    application_insights_connection_string = azurerm_application_insights.default[each.key].connection_string
    application_insights_key               = azurerm_application_insights.default[each.key].instrumentation_key
    app_scale_limit                        = 1
    http2_enabled                          = true

    application_stack {
      dotnet_version = each.value.dotnet_version
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.default[each.key].id
    ]
  }

  key_vault_reference_identity_id = azurerm_user_assigned_identity.default[each.key].id
  virtual_network_subnet_id       = azurerm_subnet.function_apps.id
  tags = merge(local.tags, {
    "hidden-link: /app-insights-instrumentation-key" : azurerm_application_insights.default[each.key].instrumentation_key,
    "hidden-link: /app-insights-resource-id" : azurerm_application_insights.default[each.key].id,
  })

  depends_on = [azurerm_key_vault_secret.secret_app_setting]
}
