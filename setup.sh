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

openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout key.pem -out cert.pem -config server_ip.conf

echo Installing Python dependencies...
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install -r app/requirements.txt
