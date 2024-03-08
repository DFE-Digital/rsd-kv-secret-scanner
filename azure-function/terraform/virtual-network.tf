resource "azurerm_virtual_network" "default" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_subnet" "default" {
  name                 = "${local.resource_prefix}-fn-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = local.resource_group.name
  address_prefixes     = ["10.0.10.0/28"]

  delegation {
    name = "Microsoft.Web.serverFarms"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_subnet" "storage" {
  name                 = "${local.resource_prefix}-sg-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = local.resource_group.name
  address_prefixes     = ["10.0.20.0/28"]

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_private_dns_zone" "storage_blob_dns" {
  name                = "${azurerm_storage_account.default.name}.blob.core.windows.net"
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob_private_link" {
  name                  = "${local.resource_prefix}-sg-blob-private-link"
  resource_group_name   = local.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob_dns.name
  virtual_network_id    = azurerm_virtual_network.default.id
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "${local.resource_prefix}-sg-blob-private-endpoint"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  subnet_id           = azurerm_subnet.storage.id

  private_service_connection {
    name                           = "${local.resource_prefix}storageconnection-blob"
    private_connection_resource_id = azurerm_storage_account.default.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = local.tags
}

resource "azurerm_private_dns_a_record" "storage_blob_private_link" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.storage_blob_dns.name
  resource_group_name = local.resource_group.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage_blob.private_service_connection[0].private_ip_address]
  tags                = local.tags
}
