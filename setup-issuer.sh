#!/usr/bin/env bash

if [ "$1" == "-h" ]; then
    echo "Usage: setup-issuer.sh [IP] [HOSTNAME]"
    echo
    echo "IP         the local IP of the issuer, empty for autodetection"
    echo "HOSTNAME   the hostname of the issuer (optional)"
    exit
fi

./scripts/setup-venv.sh
./scripts/setup-cert.sh $1 $2
cp app/app_config/__config_secrets.py app/app_config/config_secrets.py

if [ "$2" != "" ]; then
    ISSUER_LOCATION=$2
elif [ "$1" != "" ]; then
    ISSUER_LOCATION=$1
else
    ISSUER_LOCATION=$(./resolve-ip.sh)
fi
./scripts/setup-issuer-metadata.sh ${ISSUER_LOCATION}
