#! /bin/bash
set -e

TZ=Europe/London
TODAY=$(date -Idate)
DATE_90=$(date --date="90 days ago" +"%Y-%m-%d")
SILENT=0

NOTIFY=1

if [ -z "$SLACK_WEBHOOK_URL" ]; then
  NOTIFY=0
fi

################################################################################
# Author:
#   Ash Davies <@DrizzlyOwl>
# Version:
#   0.1.0
# Description:
#   Search an Azure Subscription for Azure Key Vaults that have Secrets with
#   expiry dates. If an expiry date is due within the next 90 days report it
# Usage:
#   ./kv-secret-scan.sh [-s <subscription name>] [-q]
#      -s       <subscription name>      (optional) Azure Subscription
#      -q                                (optional) Suppress output
#
#   If you do not specify the subscription name, the script will prompt you to
#   select one based on the current logged in Azure user
################################################################################

while getopts "s:q" opt; do
  case $opt in
    s)
      AZ_SUBSCRIPTION_SCOPE=$OPTARG
      ;;
    q)
      SILENT=1
      ;;
    *)
      ;;
  esac
done

# If a subscription scope has not been defined on the command line using '-e'
# then prompt the user to select a subscription from the account
if [ -z "${AZ_SUBSCRIPTION_SCOPE}" ]; then
  AZ_SUBSCRIPTIONS=$(
    az account list --output json |
    jq -c '[.[] | select(.state == "Enabled").name]'
  )

  echo "🌐 Choose an option"
  AZ_SUBSCRIPTIONS="$(echo "$AZ_SUBSCRIPTIONS" | jq -r '. | join(",")')"

  # Read from the list of available subscriptions and prompt them to the user
  # with a numeric index for each one
  if [ -n "$AZ_SUBSCRIPTIONS" ]; then
    IFS=',' read -r -a array <<< "$AZ_SUBSCRIPTIONS"

    echo
    cat -n < <(printf "%s\n" "${array[@]}")
    echo

    n=""

    # Ask the user to select one of the indexes
    while true; do
        read -rp 'Select subscription to query: ' n
        # If $n is an integer between one and $count...
        if [ "$n" -eq "$n" ] && [ "$n" -gt 0 ]; then
          break
        fi
    done

    i=$((n-1)) # Arrays are zero-indexed
    AZ_SUBSCRIPTION_SCOPE="${array[$i]}"
  fi
fi

echo "🎯 Using subscription $AZ_SUBSCRIPTION_SCOPE"
echo

echo "🔎 Looking for Azure Key Vaults..."

# Find all Azure Key Vaults within the specified subscription
KV_LIST=$(
  az keyvault list \
    --only-show-errors \
    --subscription "$AZ_SUBSCRIPTION_SCOPE" |
  jq -rc '.[] | { "name": .name, "resourceGroup": .resourceGroup }'
)

STATUS=0

for KEY_VAULT in $KV_LIST; do
  BIN_EXPIRED=""
  BIN_EXPIRING=""
  RESOURCE_GROUP=$(echo "$KEY_VAULT" | jq -rc '.resourceGroup')
  KV_NAME=$(echo "$KEY_VAULT" | jq -rc '.name')

  if [ $SILENT == 1 ]; then
    echo "  🔐 Azure Key Vault found..."
  else
    echo "  🔐 Azure Key Vault $KV_NAME in Resource Group $RESOURCE_GROUP..."
  fi

  echo "    🕵️ 🔎  Looking for Secrets..."

  SECRETS=$(
    az keyvault secret list \
      --vault-name "$KV_NAME" \
      --output json \
      --only-show-errors \
      --subscription "$AZ_SUBSCRIPTION_SCOPE" |
    jq '.[] | select(.attributes.enabled == true) | select(.attributes.expires != null) | { "secret_name": .name, "expiry_date": .attributes.expires }'
  )

  if [ -z "$SECRETS" ]; then
    echo "      ✅  No Secrets found!"
  else
    for SECRET in $(echo "$SECRETS" | jq -c); do
      SECRET_NAME=$(echo "$SECRET" | jq -rc '.secret_name')
      SECRET_EXPIRY=$(echo "$SECRET" | jq -rc '.expiry_date')

      if [ $SILENT == 1 ]; then
        echo "      🔑  Checking Secret..."
      else
        echo "      🔑  Checking Secret: $SECRET_NAME..."
      fi

      # Check expiry of existing token
      SECRET_EXPIRY_EXPIRY_DATE=${SECRET_EXPIRY:0:10}
      SECRET_EXPIRY_EXPIRY_DATE_COMP=${SECRET_EXPIRY_EXPIRY_DATE//-/}
      DATE_90=${DATE_90:0:10}
      DATE_90_COMP=${DATE_90//-/}
      TODAY_COMP=${TODAY//-/}

      if [ $SILENT == 0 ]; then
        echo "          Expires on $SECRET_EXPIRY_EXPIRY_DATE"
      fi

      if [[ "$SECRET_EXPIRY_EXPIRY_DATE_COMP" -lt "$TODAY_COMP" ]] || [[ "$SECRET_EXPIRY_EXPIRY_DATE_COMP" == "$TODAY_COMP" ]]; then
        echo "          ❌  Expired"
        BIN_EXPIRED="$SECRET, $BIN_EXPIRED"
      elif [[ "$SECRET_EXPIRY_EXPIRY_DATE_COMP" -lt "$DATE_90_COMP" ]]; then
        echo "          ⏳  Expiring in less than 90 days"
        BIN_EXPIRING="$SECRET, $BIN_EXPIRING"
      else
        echo "          ✅  Still valid"
      fi
      echo
    done
  fi

  if [ "$BIN_EXPIRING" == "" ] && [ "$BIN_EXPIRED" == "" ]; then
    if [ $NOTIFY == 1 ]; then
      BODY=""
      export BODY
      bash ./notify.sh \
        -t "Key Vault Scan finished for $KV_NAME" \
        -l "✅ No Secrets were found with expiry dates less than 90 days away" \
        -c "#50C878" \
        -d "*Key Vault:* $KV_NAME    *Resource Group:* $RESOURCE_GROUP"
    fi
  else
    STATUS=1

    if [ "$BIN_EXPIRING" != "" ]; then
      BIN_EXPIRING="[${BIN_EXPIRING/%, /}]"

      echo
      echo "⚠️ Secrets were found that are close to expiry, you should renew them"

      if [ $SILENT == 0 ]; then
        echo "Key Vault: $KV_NAME"
        echo "$BIN_EXPIRING" | jq -c '.[].secret_name'
      fi

      echo

      if [ $NOTIFY == 1 ]; then
        JSON_SECRETS=$(
          echo "$BIN_EXPIRING" |
          jq -r \
            --arg kvn "${KV_NAME}" \
            '.[] | [
              {
                text: (.secret_name | "<https://portal.azure.com/?feature.msaljs=true#@platform.education.gov.uk/asset/Microsoft_Azure_KeyVault/Secret/https://"+$kvn+".vault.azure.net/secrets/"+.+"|"+.+">"),
                type: "mrkdwn"
              },
              {
                text: .expiry_date,
                type: "plain_text"
              }
            ]'
        )

        BODY=$(
          jq -n \
            --arg kvn "$KV_NAME" \
            --arg rg "$RESOURCE_GROUP" \
            --argjson secrets "$JSON_SECRETS" \
            '[
              {
                text: "*Secret Name*",
                type: "mrkdwn"
              },
              {
                text: "*Expiry Date*",
                type: "mrkdwn"
              }
            ] | . += $secrets'
        )

        export BODY

        bash ./notify.sh \
            -t "Key Vault Scan finished for $KV_NAME" \
            -l "💣 These Secrets are close to expiry, you should renew them" \
            -c "#FFA500" \
            -d "*Key Vault:* $KV_NAME    *Resource Group:* $RESOURCE_GROUP"
      fi
    fi
    if [ "$BIN_EXPIRED" != "" ]; then
      BIN_EXPIRED="[${BIN_EXPIRED/%, /}]"

      echo
      echo "💣 Secrets were found that have expired, you should remove them if they are not in use"

      if [ $SILENT == 0 ]; then
        echo "Key Vault: $KV_NAME"
        echo "$BIN_EXPIRED" | jq -c '.[].secret_name'
      fi

      echo

      if [ $NOTIFY == 1 ]; then
        JSON_SECRETS=$(
          echo "$BIN_EXPIRED" |
          jq -r \
            --arg kvn "${KV_NAME}" \
            '.[] | [
              {
                text: (.secret_name | "<https://portal.azure.com/?feature.msaljs=true#@platform.education.gov.uk/asset/Microsoft_Azure_KeyVault/Secret/https://"+$kvn+".vault.azure.net/secrets/"+.+"|"+.+">"),
                type: "mrkdwn"
              },
              {
                text: .expiry_date,
                type: "plain_text"
              }
            ]'
        )

        BODY=$(
          jq -n \
            --arg kvn "$KV_NAME" \
            --arg rg "$RESOURCE_GROUP" \
            --argjson secrets "$JSON_SECRETS" \
            '[
              {
                text: "*Secret Name*",
                type: "mrkdwn"
              },
              {
                text: "*Expiry Date*",
                type: "mrkdwn"
              }
            ] | . += $secrets'
        )

        export BODY

        bash ./notify.sh \
            -t "Key Vault Scan finished for $KV_NAME" \
            -l "💣 These Secrets have already expired, you should remove them if they are not in use" \
            -c "#FF0000" \
            -d "*Key Vault:* $KV_NAME    *Resource Group:* $RESOURCE_GROUP"
      fi
    fi
  fi
done

exit $STATUS
