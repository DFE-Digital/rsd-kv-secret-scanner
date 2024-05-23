FROM mcr.microsoft.com/azure-cli
LABEL org.opencontainers.image.source=https://github.com/DFE-Digital/rsd-kv-secret-scanner

RUN apk add curl

COPY kv-secretn-scan.sh /
RUN chmod +x /kv-secretn-scan.sh

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

COPY notify.sh /
COPY slack-webhook.json /
RUN chmod +x /notify.sh
