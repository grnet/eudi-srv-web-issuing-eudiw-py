#!/usr/bin/env bash

if [ "$1" == "-h" ]; then
    echo "Usage: setup-issuer.sh [IP]"
    echo
    echo "IP      the local IP of the issuer, empty for autodetection"
    exit
fi

./scripts/setup-venv.sh
./scripts/setup-cert.sh $1
cp app/app_config/__config_secrets.py app/app_config/config_secrets.py

./scripts/setup-issuer-metadata.sh $1
