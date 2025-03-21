#!/usr/bin/env bash

if [ "$1" == "-h" ]; then
    echo "Usage: setup-issuer-metadata.sh [ISSUER]"
    echo
    echo "IP      the local IP/hostname of the issuer, empty for IP autodetection"
    exit
elif [ "$1" == "" ]; then
    LOCAL_ADDR=$(cat .config.ip)
else
    LOCAL_ADDR=$1
fi

git restore app/metadata_config/metadata_config.json app/metadata_config/oauth-authorization-server.json app/metadata_config/openid-configuration.json
git grep issuer.eudiw.dev | fgrep --color=none .json | cut -d ':' -f 1 | sort -u | xargs sed -i -e "s/https:\/\/issuer.eudiw.dev/https:\/\/${LOCAL_ADDR}:5000/g"
