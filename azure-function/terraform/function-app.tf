resource "azurerm_service_plan" "default" {
  name                = "${local.resource_prefix}-serviceplan"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  os_type             = local.service_plan_os
  sku_name            = local.service_plan_sku

  tags = local.tags
}

resource "azurerm_linux_function_app" "app" {
  name                = "${local.resource_prefix}-func"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location

  storage_account_name       = azurerm_storage_account.default.name
  storage_account_access_key = azurerm_storage_account.default.primary_access_key
  service_plan_id            = azurerm_service_plan.default.id

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = true

  https_only = true

  app_settings = local.function_app_settings

  site_config {
    always_on                              = true
    application_insights_connection_string = azurerm_application_insights.default.connection_string
    application_insights_key               = azurerm_application_insights.default.instrumentation_key
    app_scale_limit                        = 1
    http2_enabled                          = true

    application_stack {
      node_version = local.function_app_node_version
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.default.id
    ]
  }

  key_vault_reference_identity_id = azurerm_user_assigned_identity.default.id
  virtual_network_subnet_id       = azurerm_subnet.default.id
  tags = merge(local.tags, {
    "hidden-link: /app-insights-instrumentation-key" : azurerm_application_insights.default.instrumentation_key,
    "hidden-link: /app-insights-resource-id" : azurerm_application_insights.default.id,
  })
}
