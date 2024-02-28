resource "azurerm_virtual_network" "default" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_subnet" "default" {
  name                 = "${local.resource_prefix}-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = local.resource_group.name
  address_prefixes     = ["10.0.0.0/23"]
}
