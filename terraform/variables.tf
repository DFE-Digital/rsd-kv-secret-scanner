variable "azure_client_id" {
  description = "Service Principal Client ID"
  type        = string
}

variable "azure_client_secret" {
  description = "Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Service Principal Tenant ID"
  type        = string
}

variable "azure_subscription_id" {
  description = "Service Principal Subscription ID"
  type        = string
}

variable "registry_server" {
  description = "Hostname of the Container Registry"
  type        = string
}

variable "registry_username" {
  description = "Username for authenticating to the Container Registry"
  type        = string
  default     = ""
}

variable "registry_password" {
  description = "Password for authenticating to the Container Registry"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "key_vault_access_ipv4" {
  description = "List of IPv4 Addresses that are permitted to access the Key Vault"
  type        = list(string)
}

variable "tfvars_filename" {
  description = "tfvars filename. This file is uploaded and stored encrypted within Key Vault, to ensure that the latest tfvars are stored in a shared place."
  type        = string
}

variable "slack_webhook_url" {
  description = "A Slack Webhook URL that the script can route messages to"
  sensitive   = true
  type        = string
  default     = ""
}

variable "key_vault_targets" {
  description = "List of Key Vault resource names and resource groups that you want the Scanner to be able to access"
  type = map(object({
    name                = string
    resource_group_name = string
  }))
  default = {}
}

variable "api_connection_client_id" {
  description = "Service Principal Client ID used for authenticating with the Container Instance "
  type        = string
  default     = ""
}

variable "api_connection_client_secret" {
  description = "Service Principal Client Secret used for authenticating with the Container Instance"
  type        = string
  default     = ""
  sensitive   = true
}
