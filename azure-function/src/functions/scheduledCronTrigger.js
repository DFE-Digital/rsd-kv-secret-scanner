require("dotenv/config");
const { IncomingWebhook } = require('@slack/webhook');
const { DefaultAzureCredential, ManagedIdentityCredential, ChainedTokenCredential } = require("@azure/identity");
const { app } = require('@azure/functions');
const { KeyVaultManagementClient } = require("@azure/arm-keyvault")
const { SecretClient } = require("@azure/keyvault-secrets");
const { setLogLevel } = require("@azure/logger");
const { SubscriptionClient } = require("@azure/arm-subscriptions");

const environment = process.env.NODE_ENV

// Set logging level to "warning" for Prod, or "info" for Dev
const logLevel = environment && environment === "production" ? "error" : "warning"
console.info("Setting Log Level to", logLevel)
setLogLevel(logLevel)

// These are environment variables that should be passed to the Azure function
// const azure_tenantId = process.env["AZURE_TENANT_ID"];
// const azure_clientId = process.env["AZURE_CLIENT_ID"];
// const azure_secret = process.env["AZURE_CLIENT_SECRET"];
const azure_uami_clientId = process.env["AZURE_UAMI_CLIENT_ID"];
const azure_subscription = process.env["AZURE_SUBSCRIPTION"];
const slack_webhook_url = process.env["SLACK_WEBHOOK_URL"];

let today = new Date()

const credentials = getCredentials()

/**
 * Load an appropriate set of credentials
 * @returns DefaultAzureCredential
 */
function getCredentials() {
  try {
    let uamiCredentials = null
    if (environment == "production" && azure_uami_clientId) {
      uamiCredentials = new ManagedIdentityCredential(azure_uami_clientId)
    }

    return new ChainedTokenCredential(
      uamiCredentials,
      DefaultAzureCredential()
    )
  } catch (err) {
    if (err.name == "RestError" && err.statusCode == 403) {
      console.error(err.details.error.innerError)
    } else {
      console.error(err);
    }
    return null
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
      console.log("Loaded Subscription from Environment", azure_subscription)
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
  } catch (err) {
    if (err.name == "RestError" && err.statusCode == 403) {
      console.error(err.details.error.innerError)
    } else {
      console.error(err);
    }
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
      console.error(err.details.error.innerError)
    } else {
      console.error(err);
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
    console.error(err);
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

    console.log("Processing Subscription", subscriptionName)

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

      console.log("Processing Key Vault", keyVaultName)

      if (keyVaultSecrets.length == 0) {
        console.log("No secrets found for this Key Vault");
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

          console.log(message)

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
    console.log("Loaded Slack Webhook URL from Environment");
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
  /**
   * Query the authenticated user's identity for all available Subscriptions
   */
  let subscriptions = await getSubscriptions()

  /**
   * For each Subscription, Get a list of Key Vault IDs
   */
  for (let subscription of subscriptions) {
    const keyVaults = await getKeyVaults(subscription)

    subscription.keyVaults = keyVaults

    /**
     * Once we have a list of Key Vaults for each Subscription
     * then we can iterate through each one and query all of the Secrets
     */
    for (let keyVault of subscription.keyVaults) {
      const keyVaultSecrets = await getKeyVaultSecrets(keyVault)

      keyVault.keyVaultSecrets = keyVaultSecrets
    }
  }

  /**
   * Check each Secret and output a message based on the state of the expiry
   */
  notifyOnExpiry(subscriptions)
}

/**
 * Register a time-based invocation of the 'main' function
 */
app.timer('scheduledCronTrigger', {
  schedule: '0 0 3 * * *',
  handler: start
});

/**
 * Start the script
 */
start()
