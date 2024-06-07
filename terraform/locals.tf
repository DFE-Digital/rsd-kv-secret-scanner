locals {
  region                             = "westeurope"
  environment                        = var.environment
  project_name                       = "rsd-kvscanner"
  resource_prefix                    = "${local.environment}${local.project_name}"
  registry_server                    = var.registry_server
  registry_username                  = var.registry_username
  registry_password                  = var.registry_password
  registry_image_name                = "rsd-kv-secret-scanner"
  registry_image_tag                 = "latest"
  job_cpu                            = 0.5
  job_memory                         = 1
  virtual_network_address_space      = "172.16.0.0/12"
  virtual_network_address_space_mask = element(split("/", local.virtual_network_address_space), 1)
  container_apps_infra_subnet_cidr   = cidrsubnet(local.virtual_network_address_space, 21 - local.virtual_network_address_space_mask, 0)
  key_vault_access_ipv4              = var.key_vault_access_ipv4
  tfvars_filename                    = var.tfvars_filename
  slack_webhook_url                  = var.slack_webhook_url
  tags                               = var.tags
}
