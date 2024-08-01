resource "azurerm_logic_app_workflow" "logicapp" {
  count = (local.api_connection_client_id != "" && local.api_connection_client_secret != "") ? 1 : 0

  name                = local.resource_prefix
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  parameters = { "$connections" = jsonencode({
    "${azurerm_api_connection.linkedservice[0].name}" = {
      connectionId   = azurerm_api_connection.linkedservice[0].id
      connectionName = azurerm_api_connection.linkedservice[0].name
      id             = data.azurerm_managed_api.container_instance_group.id
    }
  }) }

  workflow_parameters = { "$connections" = jsonencode({
    defaultValue = {}
    type         = "Object"
  }) }

  tags = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "logicapp" {
  count = (local.api_connection_client_id != "" && local.api_connection_client_secret != "") ? 1 : 0

  name                       = local.resource_prefix
  target_resource_id         = azurerm_logic_app_workflow.logicapp[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.default.id

  enabled_log {
    category = "WorkflowRuntime"
  }

  # The below metrics are kept in to avoid a diff in the Terraform Plan output
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}

resource "azurerm_logic_app_trigger_recurrence" "start" {
  count = (local.api_connection_client_id != "" && local.api_connection_client_secret != "") ? 1 : 0

  name         = "scheduled-start"
  time_zone    = "W. Europe Standard Time"
  logic_app_id = azurerm_logic_app_workflow.logicapp[0].id
  frequency    = "Day"
  interval     = 1

  schedule {
    at_these_hours   = [06]
    at_these_minutes = [30]
  }
}

resource "azurerm_logic_app_action_custom" "start" {
  name         = "start-aci"
  logic_app_id = azurerm_logic_app_workflow.logicapp[0].id

  body = <<BODY
  {
    "inputs": {
      "host": {
        "connection": {
          "name": "@parameters('$connections')['${azurerm_api_connection.linkedservice[0].name}']['connectionId']"
        }
      },
      "method": "post",
      "path": "${azurerm_container_group.default.id}/start",
      "queries": {
        "x-ms-api-version": "2019-12-01"
      }
    },
    "runAfter": {},
    "type": "ApiConnection"
  }
  BODY
}
