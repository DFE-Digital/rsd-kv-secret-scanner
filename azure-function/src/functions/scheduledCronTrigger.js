require("dotenv/config");
const { IncomingWebhook } = require('@slack/webhook');
const { ManagedIdentityCredential, AzureCliCredential, ClientSecretCredential, AzureDeveloperCliCredential, DefaultAzureCredential } = require("@azure/identity");
const { app, HttpRequest } = require('@azure/functions');
const { KeyVaultManagementClient } = require("@azure/arm-keyvault")
const { SecretClient } = require("@azure/keyvault-secrets");
const { setLogLevel } = require("@azure/logger");
const { SubscriptionClient } = require("@azure/arm-subscriptions");

const environment = process.env["APPSETTING_NODE_ENV"] || process.env["NODE_ENV"];
console.log("Node Environment set to", environment)

// Set logging level to "warning" for Prod, or "info" for Dev
const logLevel = environment && environment === "production" ? "error" : "info"
console.info("Setting Log Level to", logLevel)
setLogLevel(logLevel)

// These are environment variables that should be passed to the Azure function
const azure_tenantId = process.env["AZURE_TENANT_ID"];
const azure_clientId = process.env["AZURE_CLIENT_ID"];
const azure_secret = process.env["AZURE_CLIENT_SECRET"];
const azure_uami = process.env["AZURE_USE_UAMI"];
const azure_subscription = process.env["AZURE_SUBSCRIPTION"];
const slack_webhook_url = process.env["SLACK_WEBHOOK_URL"];

let today = new Date()

let credentials

/**
 * Initialise the authentication handler and begin
 * @returns void
 */
function init(request, context) {
  /**
   * Make Context available to all
   */
  process.context = context

  /**
   * Determine if the authentication was successful
   */
  credentials = getCredentials(context)

  /**
   * If credentials is not null, then we can try to grab a Bearer token
   */
  if (credentials) {
    context.log("Testing credentials by acquiring a token...")

    credentials.getToken().then((token) => {
      context.log("Successfully acquired token")
      start()
    }, (CredentialUnavailableError) => {
      context.error("Failed to acquire a token", CredentialUnavailableError)
    })
  }
}

/**
 * Load an appropriate set of credentials
 * @returns DefaultAzureCredential
 */
function getCredentials() {
  let credential = null

  try {
    if (azure_uami && azure_clientId) {
      process.context.log("Loaded UAMI Client ID from Environment", azure_clientId)
      credential = new ManagedIdentityCredential(azure_clientId)
      return credential
    }

    if (azure_tenantId, azure_clientId, azure_secret) {
      process.context.log("Loaded Service Principal from Environment", azure_clientId)
      credential = new ClientSecretCredential(azure_tenantId, azure_clientId, azure_secret)
      return credential
    }

    if (environment == "development") {
      process.context.log("Trying development credentials")
      credential = new AzureDeveloperCliCredential()
      return credential
    }

    process.context.log("Trying fallback credentials")
    credential = new DefaultAzureCredential()
    return credential
  } catch (err) {
    process.context.error("An error occurred handling the credentials", err)
    return null
  } finally {
    process.context.log("Settled on using", credential)
  }
}

/**
 * Query for all Subscriptions available to the authenticated user and get the
 * Subscription ID for each one
 * @returns Promise[]
 */
async function getSubscriptions() {
  let subscriptionsIds = [];

  try {
    const client = new SubscriptionClient(credentials);

    if (azure_subscription && null !== azure_subscription) {
      process.context.log("Loaded Subscription from Environment", azure_subscription)
      subscriptionsIds.push(await collect(client, azure_subscription))
    } else {
      for await (const item of client.subscriptions.list()) {
        subscriptionsIds.push(await collect(client, item.id))
      }
    }

    async function collect (client, subscriptionId) {
      const subscriptionDetails = await client.subscriptions.get(
        subscriptionId
      );

      if (subscriptionDetails.state == "Enabled") {
        const { displayName } = subscriptionDetails

        return { "subscriptionId": subscriptionId, "subscriptionName": displayName }
      }
    }
  } catch (RestError) {
    const err = JSON.parse(RestError.message).error
    const status = RestError.statusCode

    process.context.error("HTTP " + status, err.code, err.message)
  }

  return subscriptionsIds
}

/**
 * Query for all Key Vaults available to the authenticated user
 * @param object subscription
 * @returns array
 */
async function getKeyVaults(subscription) {
  const { subscriptionId, subscriptionName } = subscription

  let keyVaults = [];

  try {
    const client = new KeyVaultManagementClient(credentials, subscriptionId)

    for await (const kv of client.vaults.listBySubscription()) {
      const { id, properties, name } = kv
      const { vaultUri } = properties

      if (properties.provisioningState == "Succeeded") {
        const data = {
          "keyVaultId": id,
          "keyVaultUri": vaultUri,
          "keyVaultName": name
        }

        keyVaults.push(data)
      }
    }
  } catch (err) {
    if (err.name == "RestError" && err.statusCode == 403) {
      process.context.error(err.details.error.innerError)
    } else {
      process.context.error(err);
    }
  }

  return keyVaults
}

/**
 * Query for all secrets within a Key Vault and return a list of Secrets that
 * are due to, or have already, expired
 * @param object
 * @returns array
 */
async function getKeyVaultSecrets(keyVault) {
  const { keyVaultID, keyVaultUri } = keyVault
  let secrets = [];

  try {
    const client = new SecretClient(keyVaultUri, credentials)

    for await (const secretProperties of client.listPropertiesOfSecrets()) {
      const { name } = secretProperties
      const { properties } = await client.getSecret(name);

      if (properties.enabled && properties.expiresOn) {
        const secretExpiryDate = properties.expiresOn
        const expiryDateCompare = secretExpiryDate.toTimeString()
        const todayCompare = today.toTimeString()
        const less90daysCompare = new Date(
          secretExpiryDate.getUTCFullYear(),
          secretExpiryDate.getUTCMonth(),
          secretExpiryDate.getUTCDate() - 90 // days
        ).toTimeString()

        // Is the expiry date before today?
        const isExpired = Math.abs(expiryDateCompare - todayCompare) < 0 ? true : false
        // Is the expiry date in the next 90 days?
        const isExpiring = Math.abs(less90daysCompare - todayCompare) < 0 ? true : false;
        const state = isExpired ? "expired" : isExpiring ? "expiring" : "valid"

        const data = {
          "secretName": name,
          "secretExpiresOn": properties.expiresOn,
          "secretState": state
        }

        secrets.push(data)
      }
    }
  } catch (err) {
    process.context.error(err);
  }

  return secrets
}

/**
 * Iterate through each Key Vault Secret and notify/log a secret's state
 * @param array subscriptions
 */
function notifyOnExpiry(subscriptions) {
  let blocks = []

  for (const subscription of subscriptions) {
    const { subscriptionId, subscriptionName, keyVaults } = subscription

    process.context.log("Processing Subscription", subscriptionName)

    blocks.push({
      type: "header",
      text: {
        text: "Key Vault Secret Scanner",
        type: "plain_text"
      }
    })

    blocks.push({
      type: "section",
      text: {
        text: ":key: *Subscription:* " + subscriptionName,
        type: "mrkdwn"
      }
    })

    for (const keyVault of keyVaults) {
      const { keyVaultName, keyVaultSecrets } = keyVault

      process.context.log("Processing Key Vault", keyVaultName)

      if (keyVaultSecrets.length == 0) {
        process.context.log("No secrets found for this Key Vault");
      } else {
        blocks.push({
          type: "section",
          text: {
            text: ":lock: *Key Vault:* " + keyVaultName,
            type: "mrkdwn"
          }
        })

        let childblocks = []
        for (const secret of keyVaultSecrets) {
          const { secretName, secretExpiresOn, secretState } = secret
          let message

          switch (secretState) {
            case "expiring":
              message = "Secret `" + secretName + "` is expiring within the next 90 days"
              emoji = ":warning:"
              break;

            case "expired":
              message = "Secret `" + secretName + "` has expired"
              emoji = ":rotating_light:"
            break;

            case "valid":
            default:
              message = "Secret `" + secretName + "` is still valid"
              emoji = ":white_check_mark:"
              break;
          }

          process.context.log(message)

          childblocks.push({
            text: secretName,
            type: "plain_text"
          })

          childblocks.push({
            text: secretState + " " + emoji,
            type: "plain_text",
            emoji: true
          })
        }

        blocks.push({
          type: "section",
          fields: childblocks
        })
      }
    }
  }

  if (null !== slack_webhook_url) {
    process.context.log("Loaded Slack Webhook URL from Environment");
    const webhook = new IncomingWebhook(slack_webhook_url)

    blocks.push({
      type: "context",
      elements: [
        {
          type: "plain_text",
          text: "Sent from: kv-secret-scanner"
        },
        {
          type: "plain_text",
          text: "GitHub: https://github.com/DFE-Digital/rsd-kv-secret-scanner"
        }
      ]
    })

    webhook.send({
      blocks: blocks
    })
  }
}

async function start() {
  process.context.log("===== Beginning execution =====")

  /**
   * Query the authenticated user's identity for all available Subscriptions
   */
  let subscriptions = await getSubscriptions()

  /**
   * For each Subscription, Get a list of Key Vault IDs
   */
  if (subscriptions.length) {
    for (let subscription of subscriptions) {
      const keyVaults = await getKeyVaults(subscription)

      subscription.keyVaults = keyVaults

      /**
       * Once we have a list of Key Vaults for each Subscription
       * then we can iterate through each one and query all of the Secrets
       */
      if (subscription.keyVaults.length) {
        for (let keyVault of subscription.keyVaults) {
          const keyVaultSecrets = await getKeyVaultSecrets(keyVault)

          keyVault.keyVaultSecrets = keyVaultSecrets
        }
      }
    }

    /**
     * Check each Secret and output a message based on the state of the expiry
     */
    notifyOnExpiry(subscriptions)
  } else {
    process.context.error("No Subscriptions were loaded")
  }
}

/**
 * Register a time-based invocation of the 'main' function
 */
app.timer('scheduledCronTrigger', {
  schedule: '0 0 3 * * *',
  handler: init
});

app.get('start', {
  handler: init
})
