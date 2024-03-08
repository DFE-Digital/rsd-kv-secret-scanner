resource "azurerm_storage_account" "default" {
  name                            = replace(local.resource_prefix, "-", "")
  resource_group_name             = local.resource_group.name
  location                        = local.resource_group.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}

resource "azurerm_storage_account_network_rules" "default" {
  storage_account_id         = azurerm_storage_account.default.id
  default_action             = "Deny"
  bypass                     = []
  virtual_network_subnet_ids = [azurerm_subnet.storage.id]
}
