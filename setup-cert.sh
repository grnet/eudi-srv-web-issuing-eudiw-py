#!/usr/bin/env bash

if [ "$1" == "-h" ]; then
    echo "Set up the certificate of the issuer"
    echo "Usage: setup-cert.sh [LOCAL_IP]"
    exit
elif [ "$1" == "" ]; then
    echo $(./resolve-ip.sh) > .config.ip
else
    echo $1 > .config.ip
fi

echo "Using local address: $(cat .config.ip)"

echo Installing keys/certificates...
PRIVKEY_DIR=/etc/eudiw/pid-issuer/privKey/
CERT_DIR=/etc/eudiw/pid-issuer/cert/
sudo mkdir -p ${PRIVKEY_DIR}
sudo mkdir -p ${CERT_DIR}
sudo chmod +rx /etc/eudiw
sudo chmod +rx /etc/eudiw/pid-issuer
sudo chmod +rx ${PRIVKEY_DIR}
sudo chmod +rx ${CERT_DIR}

echo Copying signing certificates...
sudo unzip -o api_docs/test_tokens/DS-token/PID-DS-0002.zip -d ${PRIVKEY_DIR}
sudo mv ${PRIVKEY_DIR}/PID-DS-0002.cert.der ${CERT_DIR}/
sudo chmod +r ${PRIVKEY_DIR}*

echo Copying IACA files...
gunzip -f -k api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem.gz
sudo mkdir -p /etc/eudiw/pid-issuer/cert/
sudo chmod +rx /etc/eudiw/pid-issuer/cert/
sudo cp api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem /etc/eudiw/pid-issuer/cert/
if [ -f "root-ca-grnet.pem" ];
   sudo cp root-ca-grnet.pem /etc/eudiw/pid-issuer/cert/
fi

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

config_file=$(generate_config_file $(<.config.ip))

openssl req -x509 -nodes -days 730 \
    -newkey rsa:2048 \
    -keyout key.pem \
    -out cert.pem \
    -config <(printf "$config_file")
