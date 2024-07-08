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
#   0.2.0
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

# Set up a handy log output function
#
# @usage print -l 'Something happened :)'"
# @param -l <log>  Any information to output
# @param -e <0/1>  Message is an error
# @param -q <0/1>  Quiet mode
function print {
  OPTIND=1
  QUIET_MODE=0
  ERROR=0
  while getopts "l:q:e:" opt; do
    case $opt in
      l)
        LOG="$OPTARG"
        ;;
      q)
        QUIET_MODE="$OPTARG"
        ;;
      e)
        ERROR="$OPTARG"
        ;;
      *)
        exit 1
        ;;
    esac
  done

  if [ "$QUIET_MODE" == "0" ]; then
    if [ "$ERROR" == "1" ]; then
      echo "[!] $LOG" >&2
    else
      echo "$LOG"
    fi
  fi
}

# Entered a dead-end without user input
if [ $SILENT == 1 ] && [ -z "${AZ_SUBSCRIPTION_SCOPE}" ]; then
  print -l "You must specify the Subscription ID or Name when using the silent switch" -e 1 -q 0

  if [ $NOTIFY == 1 ]; then
    bash ./notify.sh \
      -t "Error: Silent switch is used but no Subscription scope was specified. Unable to continue"
  fi

  exit 1
fi

# If a subscription scope has not been defined on the command line using '-e'
# then prompt the user to select a subscription from the account
if [ -z "${AZ_SUBSCRIPTION_SCOPE}" ]; then
  AZ_SUBSCRIPTIONS=$(
    az account list --output json |
    jq -c '[.[] | select(.state == "Enabled").name]'
  )

  print -l "Choose an option: " -e 0 -q 0
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

if [ $NOTIFY == 1 ]; then
  bash ./notify.sh \
    -t "🎯 *Key Vault Secret Expiry Scan task started in \`$AZ_SUBSCRIPTION_SCOPE\`*"
fi

print -l "Subscription: $AZ_SUBSCRIPTION_SCOPE" -q 0 -e 0

# Find all Azure Key Vaults within the specified subscription
KV_LIST=$(
  az keyvault list \
    --only-show-errors \
    --subscription "$AZ_SUBSCRIPTION_SCOPE" |
  jq -rc '.[] | { "name": .name, "resourceGroup": .resourceGroup }'
)

COUNT_KEY_VAULT=0
TOTAL_SECRET_COUNT=0
TOTAL_EXPIRING_COUNT=0
TOTAL_EXPIRED_COUNT=0

for KEY_VAULT in $KV_LIST; do
  COUNT_KEY_VAULT=$((COUNT_KEY_VAULT+1))
  BIN_EXPIRED=""
  BIN_EXPIRING=""
  BIN_VALID=""
  KV_NAME=$(echo "$KEY_VAULT" | jq -rc '.name')

  print -l "Azure Key Vault: $KV_NAME" -q 0 -e 0

  SECRETS=$(
    az keyvault secret list \
      --vault-name "$KV_NAME" \
      --output json \
      --only-show-errors \
      --subscription "$AZ_SUBSCRIPTION_SCOPE" |
    jq '.[] | select(.attributes.enabled == true) | select(.attributes.expires != null) | { "secret_name": .name, "expiry_date": .attributes.expires }'
  )

  if [ -z "$SECRETS" ]; then
    print -l "No secrets with expiry dates found" -q $SILENT -e 0
    continue
  else
    for SECRET in $(echo "$SECRETS" | jq -c); do
      SECRET_NAME=$(echo "$SECRET" | jq -rc '.secret_name')
      SECRET_EXPIRY=$(echo "$SECRET" | jq -rc '.expiry_date')

      # Check expiry of existing token
      SECRET_EXPIRY_EXPIRY_DATE=${SECRET_EXPIRY:0:10}
      SECRET_EXPIRY_EXPIRY_DATE_COMP=${SECRET_EXPIRY_EXPIRY_DATE//-/}
      DATE_90=${DATE_90:0:10}
      DATE_90_COMP=${DATE_90//-/}
      TODAY_COMP=${TODAY//-/}

      if [[ "$SECRET_EXPIRY_EXPIRY_DATE_COMP" -lt "$TODAY_COMP" ]] || [[ "$SECRET_EXPIRY_EXPIRY_DATE_COMP" == "$TODAY_COMP" ]]; then
        SECRET_STATUS="Expired"
        BIN_EXPIRED="$SECRET, $BIN_EXPIRED"
      elif [[ "$SECRET_EXPIRY_EXPIRY_DATE_COMP" -lt "$DATE_90_COMP" ]]; then
        SECRET_STATUS="Expiring soon"
        BIN_EXPIRING="$SECRET, $BIN_EXPIRING"
      else
        SECRET_STATUS="Valid"
        BIN_VALID="$SECRET, $BIN_VALID"
      fi

      print -l "Secret: $SECRET_NAME | Expiry Date: $SECRET_EXPIRY_EXPIRY_DATE | State: $SECRET_STATUS" -q $SILENT -e 0

      if [ "$SECRET_STATUS" != "Valid" ] && [ $NOTIFY == 1 ]; then
        bash ./notify.sh \
          -t ":warning: *Key Vault:* $KV_NAME | *Secret:* <https://portal.azure.com/?feature.msaljs=true#@platform.education.gov.uk/asset/Microsoft_Azure_KeyVault/Secret/https://$KV_NAME.vault.azure.net/secrets/$SECRET_NAME|$SECRET_NAME> | *Expiry Date:* $SECRET_EXPIRY_EXPIRY_DATE"
      fi

      TOTAL_SECRET_COUNT=$((TOTAL_SECRET_COUNT+1))
    done
  fi

  if [ "$BIN_EXPIRING" == "" ] && [ "$BIN_EXPIRED" == "" ]; then
    print -l "Secrets are still valid" -q $SILENT -e 0
  else
    if [ "$BIN_EXPIRING" != "" ]; then
      BIN_EXPIRING="[${BIN_EXPIRING/%, /}]"
      BIN_EXPIRING_COUNT=$(echo "$BIN_EXPIRING" | jq -r 'length')
      BIN_EXPIRING_SECRET_NAMES=$(echo "$BIN_EXPIRING" | jq -rc '.[].secret_name')
      TOTAL_EXPIRING_COUNT=$((TOTAL_EXPIRING_COUNT + BIN_EXPIRING_COUNT))

      print -l "$BIN_EXPIRING_COUNT Secrets were found that are close to expiry. You should renew these:" -q 0 -e 0
      print -l "$BIN_EXPIRING_SECRET_NAMES" -q 0 -e 0
    fi
    if [ "$BIN_EXPIRED" != "" ]; then
      BIN_EXPIRED="[${BIN_EXPIRED/%, /}]"
      BIN_EXPIRED_COUNT=$(echo "$BIN_EXPIRED" | jq -r 'length')
      BIN_EXPIRED_SECRET_NAMES=$(echo "$BIN_EXPIRED" | jq -rc '.[].secret_name')
      TOTAL_EXPIRED_COUNT=$((TOTAL_EXPIRED_COUNT + BIN_EXPIRED_COUNT))

      print -l "$BIN_EXPIRED_COUNT Secrets were found that have expired. You should remove them if they are not in use:" -q 0 -e 0
      print -l "$BIN_EXPIRED_SECRET_NAMES" -q 0 -e 0
    fi
  fi
done

LOG_FINAL="Finished scanning $COUNT_KEY_VAULT Key Vaults and $TOTAL_SECRET_COUNT secrets. $TOTAL_EXPIRED_COUNT were expired. $TOTAL_EXPIRING_COUNT were close to expiry."

print -l "$LOG_FINAL" -q 0 -e 0

if [ $NOTIFY == 1 ]; then
  bash ./notify.sh -t "$LOG_FINAL"
fi
