#!/usr/bin/env bash

if [ -f ".config.hostname" ]; then
    HOST=$(<.config.hostname)
elif [ -f ".config.ip" ]; then
    HOST=$(<.config.ip)
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
export DEFAULT_FRONTEND_URL=https://snf-74864.ok-kno.grnetcloud.net:5602
export VERIFY_USER_ENDPOINT=https://snf-74864.ok-kno.grnetcloud.net:5601/verify/user
export AUTH_SERVER_INTERNAL_URL=https://snf-74864.ok-kno.grnetcloud.net:5601

echo "Running in branch: "$(git rev-parse --abbrev-ref HEAD)
flask --app app run --cert=cert.pem --key=key.pem --host="$HOST" --port ${FLASK_RUN_PORT}
