#!/usr/bin/env bash

HOST_IP=$(<.config.ip)

source .venv/bin/activate
export REQUESTS_CA_BUNDLE=$(realpath cert.pem)
flask --app app run --cert=cert.pem --key=key.pem --host="$HOST_IP"
