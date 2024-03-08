# Bash Script - Key Vault Secret Scanner

You must ensure you have installed `bash`, `az` (Azure CLI) and `jq`.

If you're running this on macOS you will need to change two references to `date`.

Open `kv-secret-scan.sh` in a Text Editor and replace:

```diff
-TODAY=$(date -Idate)
-DATE_90=$(date --date="90 days ago" +"%Y-%m-%d")
+TODAY=$(gdate -Idate)
+DATE_90=$(gdate --date="90 days ago" +"%Y-%m-%d")
```

## Set up
```
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}

cd ./bash/
sudo chmod +x ./kv-secret-scan.sh ./notify.sh
bash ./kv-secret-scan.sh
```
