locals {
  # Global options
  environment     = var.environment
  project_name    = var.project_name
  resource_prefix = "${local.environment}${local.project_name}"
  azure_location  = var.azure_location
  tags            = var.tags

  # Resource Group
  existing_resource_group = var.existing_resource_group
  resource_group          = local.existing_resource_group == "" ? azurerm_resource_group.default[0] : data.azurerm_resource_group.existing_resource_group[0]

  # Web App Service Plan
  service_plan_os  = "Linux"
  service_plan_sku = "B1"

  # Function App
  function_app_settings     = var.function_app_settings
  function_app_node_version = var.function_app_node_version

  # Key Vault
  key_vault_access_users = toset(var.key_vault_access_users)
  key_vault_access_ipv4  = var.key_vault_access_ipv4
  tfvars_filename        = var.tfvars_filename
}
