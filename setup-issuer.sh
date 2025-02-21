#!/usr/bin/env bash

if [ "$1" == "-h" ]; then
    echo "Usage: setup-issuer.sh [IP]"
    echo
    echo "IP      the local IP of the issuer, empty for autodetection"
    exit
fi

./setup-venv.sh
./setup-cert.sh $1
cp app/app_config/__config_secrets.py app/app_config/config_secrets.py

if [ "$1" == "" ]; then
    IP=$(cat .config.ip)
else
    IP=$1
fi
git restore app/metadata_config/metadata_config.json app/metadata_config/oauth-authorization-server.json app/metadata_config/openid-configuration.json
git grep issuer.eudiw.dev | fgrep --color=none .json | cut -d ':' -f 1 | sort -u | xargs sed -i -e "s/https:\/\/issuer.eudiw.dev/https:\/\/${IP}:5000/g"
