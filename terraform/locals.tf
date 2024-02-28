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

  # Container Job
  container_job_cpu    = 0.25
  container_job_memory = "0.5Gi"
  container_job_cron   = "0 20 * * *"
  container_job_image  = "mcr.microsoft.com/k8se/quickstart-jobs:latest"
  container_job_secrets = [
    for env_name, env_value in nonsensitive(var.container_job_env) : {
      name  = lower(replace(env_name, "_", "-"))
      value = sensitive(env_value)
    }
  ]
  container_job_env = [
    for env_name, env_value in nonsensitive(var.container_job_env) : {
      name      = env_name
      secretRef = lower(replace(env_name, "_", "-"))
    }
  ]

  # Key Vault
  key_vault_access_users = toset(var.key_vault_access_users)
  key_vault_access_ipv4  = var.key_vault_access_ipv4
  tfvars_filename        = var.tfvars_filename
}
