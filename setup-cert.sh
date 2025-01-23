#!/usr/bin/env bash

echo Installing keys/certificates...
sudo mkdir -p /etc/eudiw/pid-issuer/privkey/
sudo chmod +rx /etc/eudiw
sudo chmod +rx /etc/eudiw/pid-issuer
sudo chmod +rx /etc/eudiw/pid-issuer/privkey

sudo unzip -o api_docs/test_tokens/DS-token/PID-DS-0002.zip -d /etc/eudiw/pid-issuer/privkey/
sudo chmod +r /etc/eudiw/pid-issuer/privkey/*

gunzip -f -k api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem.gz
sudo mkdir -p /etc/eudiw/pid-issuer/cert/
sudo chmod +rx /etc/eudiw/pid-issuer/cert/
sudo cp api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem /etc/eudiw/pid-issuer/cert/


function generate_config_file()
{
    host_ip=$1
    cat << EOF
      [req]\n
      default_bits = 2048\n
      distinguished_name = req_distinguished_name\n
      x509_extensions = v3_req\n
      prompt = no\n
      [req_distinguished_name]\n
      countryName = XX\n
      stateOrProvinceName = N/A\n
      localityName = N/A\n
      organizationName = GRNET\n
      commonName = GRNET-EBSI-Issuer\n
      [v3_req]\n
      subjectAltName = @alt_names\n
      [alt_names]\n
      IP.1 = $host_ip\n
EOF
}

./resolve-ip.sh
config_file=$(generate_config_file $(<.config.ip))

openssl req -x509 -nodes -days 730 \
    -newkey rsa:2048 \
    -keyout key.pem \
    -out cert.pem \
    -config <(printf "$config_file")
