#!/usr/bin/env bash

if [ -f ".config.hostname" ]; then
    HOST=$(<.config.hostname)
    TLS="--cert=/etc/letsencrypt/live/${HOST}/fullchain.pem --key=/etc/letsencrypt/live/${HOST}/privkey.pem"
elif [ -f ".config.ip" ]; then
    HOST=$(<.config.ip)
    TLS=
else
    echo "Missing server setup, run setup_issuer.sh"
    exit
fi

source .venv/bin/activate
export REQUESTS_CA_BUNDLE=$(realpath iaca.pem)
export SERVICE_URL="https://${HOST}:5600/"
export EIDAS_NODE_URL="https://TODO1/"
export DYNAMIC_PRESENTATION_URL="https://TODO2/"
export FLASK_RUN_PORT=5600
export NONCE_KEY=$(realpath private_nonce_key.pem)
export DEFAULT_FRONTEND_URL=https://${HOST}:5602
export VERIFY_USER_ENDPOINT=https://${HOST}:5601/verify/user
export AUTH_SERVER_INTERNAL_URL=https://${HOST}:5601

echo "Running in branch: "$(git rev-parse --abbrev-ref HEAD)
flask --app app run ${TLS} --host="$HOST" --port ${FLASK_RUN_PORT}
