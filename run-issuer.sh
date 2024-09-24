#!/usr/bin/env bash

source .venv/bin/activate
export REQUESTS_CA_BUNDLE=$(realpath cert.pem)
flask --app app run --cert=cert.pem --key=key.pem --host=83.212.99.99

