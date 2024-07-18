resource "azurerm_private_endpoint" "kv" {
  for_each = local.key_vault_targets

  name                = "${local.resource_prefix}-kv.${each.value.name}"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  subnet_id           = azurerm_subnet.kv_private_endpoint[0].id

  custom_network_interface_name = "${local.resource_prefix}${each.key}-nic"

  private_service_connection {
    name                           = "${local.resource_prefix}${each.key}"
    private_connection_resource_id = data.azurerm_key_vault.target_resource[each.key].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = local.tags
}

resource "azurerm_private_dns_zone" "kv_private_link" {
  count = length(local.key_vault_targets) > 0 ? 1 : 0

  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.default.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_private_link" {
  count = length(local.key_vault_targets) > 0 ? 1 : 0

  name                  = "${local.resource_prefix}kvprivatelink"
  resource_group_name   = azurerm_resource_group.default.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_private_link[0].name
  virtual_network_id    = azurerm_virtual_network.default.id
  tags                  = local.tags
}

resource "azurerm_private_dns_a_record" "kv_private_link" {
  for_each = local.key_vault_targets

  name                = each.value.name
  zone_name           = azurerm_private_dns_zone.kv_private_link[0].name
  resource_group_name = azurerm_resource_group.default.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.kv[each.key].private_service_connection[0].private_ip_address]
  tags                = local.tags
}
