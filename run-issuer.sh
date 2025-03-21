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
export SERVICE_URL="https://${HOST}:5000/"
export EIDAS_NODE_URL="https://TODO1/"
export DYNAMIC_PRESENTATION_URL="https://TODO2/"

flask --app app run --cert=cert.pem --key=key.pem --host="$HOST"
