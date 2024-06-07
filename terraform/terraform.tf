resource "azurerm_resource_group" "default" {
  name     = local.resource_prefix
  location = local.region

  tags = local.tags
}

resource "azurerm_log_analytics_workspace" "default" {
  name                = "${local.resource_prefix}-logs"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags
}

resource "azurerm_container_group" "default" {
  name                = "${local.resource_prefix}-job"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  ip_address_type     = "Private"
  os_type             = "Linux"

  container {
    name     = "${local.resource_prefix}-containerjob"
    image    = "${local.registry_server}/${local.registry_image_name}:${local.registry_image_tag}"
    cpu      = local.job_cpu
    memory   = local.job_memory
    commands = ["/bin/bash", "-c", "./docker-entrypoint.sh"]

    ports { # bogus
      port     = 65530
      protocol = "TCP"
    }

    environment_variables = {
      "AZ_SUBSCRIPTION_SCOPE" = data.azurerm_subscription.current.display_name
      "SLACK_WEBHOOK_URL"     = local.slack_webhook_url
    }
  }

  image_registry_credential {
    server                    = local.registry_server
    user_assigned_identity_id = azurerm_user_assigned_identity.default.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.default.id]
  }

  exposed_port   = []
  restart_policy = "Never"
  subnet_ids     = [azurerm_subnet.default.id]

  tags = local.tags
}

# necessary because of: https://github.com/Azure/azure-rest-api-specs/issues/9768
resource "azapi_update_resource" "patch_logs" {
  type        = "Microsoft.ContainerInstance/containerGroups@2023-05-01"
  resource_id = azurerm_container_group.default.id

  body = jsonencode({
    properties = {
      diagnostics : {
        logAnalytics : {
          "logType" : "ContainerInstanceLogs",
          "workspaceId" : azurerm_log_analytics_workspace.default.workspace_id,
          "workspaceKey" : azurerm_log_analytics_workspace.default.primary_shared_key
        }
      },
      imageRegistryCredentials : [
        {
          "server" : local.registry_server,
          "user_assigned_identity_id" : azurerm_user_assigned_identity.default.id,
        }
      ]
    }
  })
}

resource "azurerm_virtual_network" "default" {
  name                = "${local.resource_prefix}default"
  address_space       = [local.virtual_network_address_space]
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  tags = local.tags
}

resource "azurerm_route_table" "default" {
  name                          = "${local.resource_prefix}default"
  location                      = azurerm_resource_group.default.location
  resource_group_name           = azurerm_resource_group.default.name
  disable_bgp_route_propagation = false

  tags = local.tags
}

resource "azurerm_subnet" "default" {
  name                 = "${local.resource_prefix}containerappsinfra"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = azurerm_resource_group.default.name
  address_prefixes     = [local.container_apps_infra_subnet_cidr]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet_route_table_association" "container_apps_infra_subnet" {
  subnet_id      = azurerm_subnet.default.id
  route_table_id = azurerm_route_table.default.id
}

resource "azurerm_user_assigned_identity" "default" {
  location            = azurerm_resource_group.default.location
  name                = "${local.resource_prefix}-uami-containerjob"
  resource_group_name = azurerm_resource_group.default.name

  tags = local.tags
}
