# Azure Function - Key Vault Secret Scanner

The Azure Function is written in `NodeJS`. It is configured to run every day at
03:00AM.

## Run the Function locally

You must ensure you have signed into a valid Azure user that has the Key Vault
Secret Reader Role or the `Get Secrets` & `List Secrets` ACL for Key Vaults in
a Subscription.

You must have at least the latest LTS version of NodeJS installed as well as
Docker.

1) Run `docker compose up -d` to launch `Azurite`. This will act as a Storage
Backend for your Azure Function so you don't need to attach it to a Storage
Account in Azure.
2) Run `npm install` to grab the packages needed to run the Function
3) Rename `local.settings.json.example` to `local.settings.json`. If you want to
scope the function to a specific Azure Subscription then enter the Subscription
ID into `AZURE_SUBSCRIPTION`. If you want to notify operators via Slack then
register a new Slack Webhook URL and enter it into `SLACK_WEBHOOK_URL`.
4) If you want to run this Function as a delegated Service Principal, then
populate `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET`.
5) Run `npm run start` to initialise the Function which will immediately start
the process
