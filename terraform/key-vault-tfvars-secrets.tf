# module "azurerm_key_vault" {
#   source = "github.com/DFE-Digital/terraform-azurerm-key-vault-tfvars?ref=v0.4.0"

#   environment                             = local.environment
#   project_name                            = "kvscanner"
#   existing_resource_group                 = local.resource_group.name
#   enable_log_analytics_workspace          = true
#   azure_location                          = local.azure_location
#   key_vault_access_use_rbac_authorization = false
#   key_vault_access_users                  = local.key_vault_access_users
#   key_vault_access_ipv4                   = local.key_vault_access_ipv4
#   tfvars_filename                         = local.tfvars_filename
#   tags                                    = local.tags
# }
