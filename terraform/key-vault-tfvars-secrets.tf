module "azurerm_key_vault" {
  source = "github.com/DFE-Digital/terraform-azurerm-key-vault-tfvars?ref=v0.5.1"

  environment                             = local.environment
  project_name                            = "kvss"
  existing_resource_group                 = azurerm_resource_group.default.name
  azure_location                          = local.region
  key_vault_access_use_rbac_authorization = true
  key_vault_access_users                  = []
  key_vault_access_ipv4                   = local.key_vault_access_ipv4
  tfvars_filename                         = local.tfvars_filename
  enable_diagnostic_setting               = true
  diagnostic_log_analytics_workspace_id   = azurerm_log_analytics_workspace.default.id
  tags                                    = local.tags

  depends_on = [azurerm_resource_group.default]
}
