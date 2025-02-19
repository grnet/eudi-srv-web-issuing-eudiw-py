#!/usr/bin/env bash

./setup-venv.sh
./setup-cert.sh
cp app/app_config/__config_secrets.py app/app_config/config_secrets.py

IP=$(cat .config.ip)
git grep issuer.eudiw.dev | fgrep --color=none .json | cut -d ':' -f 1 | sort -u | xargs sed -i -e "s/https:\/\/issuer.eudiw.dev/https:\/\/${IP}:5000/g"
