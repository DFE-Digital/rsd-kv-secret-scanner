# Azure Key Vault Secret Expiry Scanner

## Set up

You will need to do these steps for each Subscription in Azure.

1) Create an App Registration in Entra ID
2) Grant `Key Vault Secrets User` Role to your Service Principal for any
Azure Key Vaults you want it to scan
3) Generate a client secret for your App Registration
4) Build a JSON credential string in the following format
```json
{
  "clientId": "<Application (client) ID>",
  "clientSecret": "<Client Secret>",
  "subscriptionId": "<Subscription ID>",
  "tenantId": "<Directory (tenant) ID>"
}
```
6) On GitHub, create an 'environment' (e.g. dev) and add the JSON string as an
environment secret with the secret name `AZURE_SUBSCRIPTION_CREDENTIALS`.
7) On GitHub, on the same environment, create a second secret with the name
`AZURE_SUBSCRIPTION_NAME` and set the value to the name of your subscription.

## Notify

This script supports notifying via Slack webhook. Set the GitHub secret
`SLACK_WEBHOOK_URL` in each environment and the script will POST the information

## How this works:

Service Principals:

- s184d-kv-secret-monitor
- s184t-kv-secret-monitor
- s184p-kv-secret-monitor

Each of the SP has the relevant role assigned to it

The script held in the `bash` directory of the repo (`kv-secret-scan.sh`) is executed
against each subscription on a nightly basis using a Cron triggered GitHub Action.

The three workflows should be staggered to avoid rate limiting.
