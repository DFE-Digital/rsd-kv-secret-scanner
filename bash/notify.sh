#! /bin/bash
set -e

################################################################################
# Author:
#   Ash Davies <@DrizzlyOwl>
# Version:
#   0.1.0
# Description:
#   Dispatch a HTTP Webhook to Slack
# Usage:
#   ./notify.sh
################################################################################


usage() {
  echo "Usage: $(basename "$0")" 1>&2
  echo "  -t '<my message>'   A short message to send"
  echo "  -l '<heading>'      The heading for your text"
  echo "  -d '<description>'  Context for your message"
  echo "  -c '<#color>'       Specify a colour hex (optional)"
  exit 1
}

MORE_FIELDS=1

BODY=${BODY:-""}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}

COLOR="#007fff"
TEXT="Hello, world!"
LABEL="A thing happened!"
DESCRIPTION="This is a general notification"

if [ "$SLACK_WEBHOOK_URL" == "" ]; then
  exit
fi

if [ "$BODY" == "" ]; then
  MORE_FIELDS=0
fi

while getopts "t:c:l:d:" opt; do
  case $opt in
    t)
      TEXT=$OPTARG
      ;;
    c)
      COLOR=$OPTARG
      ;;
    l)
      LABEL=$OPTARG
      ;;
    d)
      DESCRIPTION=$OPTARG
      ;;
    *)
      usage
      ;;
  esac
done

jq \
  --arg color "${COLOR}" \
  --arg text "${TEXT}" \
  --arg label "${LABEL}" \
  --arg desc "${DESCRIPTION}" \
  '.attachments[0].color = $color |
  .attachments[0].blocks[0].text.text = $label |
  .attachments[0].blocks[1].text.text = $desc |
  .text = $text' ./slack-webhook.json > final.json

if [ $MORE_FIELDS == 1 ]; then
  BODY=$(echo "$BODY" | jq -cr)

  if [ "$BODY" != "" ]; then
    mv final.json tmp.final.json
    cat tmp.final.json |
    jq \
      --argjson fields "$BODY" \
      '.attachments[0].blocks[2].fields = $fields |
      .attachments[0].blocks[2].type = "section"' > final.json
  fi
fi

PAYLOAD=$(cat final.json)

curl -X POST -H 'Content-type: application/json' \
  --data "$PAYLOAD" "$SLACK_WEBHOOK_URL"
