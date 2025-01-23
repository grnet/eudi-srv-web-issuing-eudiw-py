#!/usr/bin/env bash
if [ "$1" == "" ]; then
    echo "Usage: patch_ip.sh IP"
    exit 1
fi

sed="sed"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	sed="sed"
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# brew install gnu-sed
	sed="gsed"
fi

echo "Using IP: $1"
for f in app/app_config/config_service.py app/app_config/oid_config.json app/metadata_config/metadata_config.json app/metadata_config/openid-configuration.json run-issuer.sh; do
    $sed -i "s/192.168.134.214/$1/g" $f
done
