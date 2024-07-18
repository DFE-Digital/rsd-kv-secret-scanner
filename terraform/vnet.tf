resource "azurerm_virtual_network" "default" {
  name                = "${local.resource_prefix}default"
  address_space       = [local.virtual_network_address_space]
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  tags = local.tags
}

resource "azurerm_route_table" "default" {
  name                = "${local.resource_prefix}default"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

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

resource "azurerm_subnet" "kv_private_endpoint" {
  count = length(local.key_vault_targets) > 0 ? 1 : 0

  name                 = "${local.resource_prefix}keyvaultsinfra"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = azurerm_resource_group.default.name
  address_prefixes     = [local.key_vault_subnet_cidr]
  service_endpoints    = ["Microsoft.KeyVault"]
}
