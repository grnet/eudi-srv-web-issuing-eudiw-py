#!/usr/bin/env bash
if [ "$1" == "" ]; then
    echo "Usage: patch_ip.sh IP"
    exit 1
fi

echo "Using IP: $1"
for f in server_ip.conf app/app_config/config_service.py app/app_config/oid_config.json app/metadata_config/metadata_config.json app/metadata_config/openid-configuration.json run-issuer.sh; do
    sed -i "s/192.168.134.214/$1/g" $f
done
