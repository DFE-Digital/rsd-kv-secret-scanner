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
