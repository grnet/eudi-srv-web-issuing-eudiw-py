#!/usr/bin/env bash

HOST_IP=$(<.config.ip)

source .venv/bin/activate
export REQUESTS_CA_BUNDLE=$(realpath iaca.pem)
export SERVICE_URL="https://${HOST_IP}:5000/"
export EIDAS_NODE_URL="https://TODO1/"
export DYNAMIC_PRESENTATION_URL="https://TODO2/"

flask --app app run --cert=cert.pem --key=key.pem --host="$HOST_IP"
