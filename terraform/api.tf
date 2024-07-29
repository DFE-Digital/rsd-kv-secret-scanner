resource "azurerm_api_connection" "linkedservice" {
  count = (local.api_connection_client_id != "" && local.api_connection_client_secret != "") ? 1 : 0

  name                = "aci"
  resource_group_name = azurerm_resource_group.default.name
  managed_api_id      = data.azurerm_managed_api.container_instance_group.id
  display_name        = "${local.resource_prefix}-job"

  parameter_values = {
    "token:clientId" : local.api_connection_client_id,
    "token:clientSecret" : local.api_connection_client_secret,
    "token:TenantId" : data.azurerm_subscription.current.tenant_id,
    "token:grantType" : "client_credentials"
  }

  lifecycle {
    # NOTE: Az API does not return sensitive values so there will always be a diff without this
    ignore_changes = [
      parameter_values
    ]
  }

  tags = local.tags
}
