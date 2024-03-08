<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.3 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 1.12.1 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 2.37.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.87.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | 2.47.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.93.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_application_insights.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_key_vault.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.secret_app_setting](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_linux_function_app.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_log_analytics_workspace.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_log_analytics_workspace.insights](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_monitor_diagnostic_setting.logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_private_dns_a_record.key_vault_private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_a_record.storage_blob_private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_zone.keyvault_dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone.storage_blob_dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.key_vault_private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_dns_zone_virtual_network_link.storage_blob_private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_private_endpoint.storage_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_resource_group.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_service_plan.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_storage_account.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account_network_rules.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_network_rules) | resource |
| [azurerm_subnet.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_user_assigned_identity.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_virtual_network.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azuread_user.key_vault_access](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/user) | data source |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.existing_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_location"></a> [azure\_location](#input\_azure\_location) | Azure location in which to launch resources. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name. Will be used along with `project_name` as a prefix for all resources. | `string` | n/a | yes |
| <a name="input_existing_resource_group"></a> [existing\_resource\_group](#input\_existing\_resource\_group) | Conditionally launch resources into an existing resource group. Specifying this will NOT create a resource group. | `string` | `""` | no |
| <a name="input_function_app_node_version"></a> [function\_app\_node\_version](#input\_function\_app\_node\_version) | Which version of Node JS to run the Function on | `number` | `18` | no |
| <a name="input_function_app_settings"></a> [function\_app\_settings](#input\_function\_app\_settings) | n/a | `map(string)` | `{}` | no |
| <a name="input_key_vault_access_ipv4"></a> [key\_vault\_access\_ipv4](#input\_key\_vault\_access\_ipv4) | List of IPv4 Addresses that are permitted to access the Key Vault | `list(string)` | n/a | yes |
| <a name="input_key_vault_access_users"></a> [key\_vault\_access\_users](#input\_key\_vault\_access\_users) | List of users that require access to the Key Vault. This should be a list of User Principle Names (Found in Active Directory) that need to run terraform | `list(string)` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name. Will be used along with `environment` as a prefix for all resources. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to be applied to all resources | `map(string)` | `{}` | no |
| <a name="input_tfvars_filename"></a> [tfvars\_filename](#input\_tfvars\_filename) | tfvars filename. This file is uploaded and stored encrupted within Key Vault, to ensure that the latest tfvars are stored in a shared place. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->