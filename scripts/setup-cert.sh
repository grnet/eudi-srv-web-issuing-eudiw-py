#!/usr/bin/env bash

LOCAL_ROOT_CA="iaca.pem"
LOCAL_ROOT_CA_KEY="iaca.key"

function install_certificates() {
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
    sudo cp ${LOCAL_ADDR}.crt.der ${CERT_DIR}/
    sudo chmod +r ${CERT_DIR}/${LOCAL_ADDR}.crt.der
    sudo cp ${LOCAL_ADDR}.key ${PRIVKEY_DIR}/
    sudo chmod +r ${PRIVKEY_DIR}/${LOCAL_ADDR}.key

    echo Copying IACA files...
    gunzip -f -k api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem.gz
    sudo mkdir -p /etc/eudiw/pid-issuer/cert/
    sudo chmod +rx /etc/eudiw/pid-issuer/cert/
    sudo cp api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem /etc/eudiw/pid-issuer/cert/
    if [ -f "${LOCAL_ROOT_CA}" ]; then
        sudo cp "${LOCAL_ROOT_CA}" /etc/eudiw/pid-issuer/cert/
    fi
}

function generate_config_file()
{
    if [ "${HOSTNAME}" != "" ]; then
        DNS_ALT_NAME="DNS.1 = ${HOSTNAME}"
    else
        DNS_ALT_NAME=""
    fi
    cat << EOF
[req]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_ext]
subjectAltName = @alt_names

[req_distinguished_name]
countryName = GR
stateOrProvinceName = Attica
localityName = N/A
organizationName = GRNET
commonName = GRNET-Issuer

[v3_ca]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=critical,CA:FALSE
keyUsage = critical,digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment
extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = ${IP}
${DNS_ALT_NAME}
EOF
}

function generate_ssl_certificate() {
    echo "== Generating SSL certificate configuration =="
    config_file=$(mktemp)
    echo "Using temporary configuration in ${config_file}"
    generate_config_file > ${config_file}
    cat ${config_file}

    if [ -f "${LOCAL_ROOT_CA}" ] && [ -f "${LOCAL_ROOT_CA_KEY}" ]; then
        CUSTOM_ROOT_CA=1
    else
        CUSTOM_ROOT_CA=0
    fi

    # No local root CA available, create a simple self-signed certificate
    if [ $CUSTOM_ROOT_CA -eq 0 ]; then
        openssl req -x509 -nodes -days 730 \
            -newkey rsa:2048 \
            -keyout ${KEY} \
            -out ${CRT} \
            -config "$config_file"
        return
    fi

    # Local root CA available, create a certificate signed by it
    echo "== Creating key =="
    KEY="key.pem"
    openssl genrsa -out ${KEY} 2048

    echo "== Creating SSL certificate signing request =="
    CSR="cert.csr"
    rm -f ${CSR}
    openssl req -new -sha256 -key ${KEY} \
        -subj "/CN=${LOCAL_ADDR}/O=GRNET/C=GR" \
        -out ${CSR}

    echo "== Verifying the request =="
    openssl req -in ${CSR} -noout -text

    echo "== Generating the SSL certificate =="
    CRT="cert.pem"
    openssl x509 -req -in ${CSR} -CA ${LOCAL_ROOT_CA} -CAkey ${LOCAL_ROOT_CA_KEY} -out ${CRT} -days 400 -sha256 -extfile "${config_file}" -extensions v3_req
    rm -f ${config_file}


    if [ $CUSTOM_ROOT_CA -eq 1 ]; then
        echo "== Verifying the certificate using root CA ${LOCAL_ROOT_CA} =="
        openssl verify -CAfile ${LOCAL_ROOT_CA} -purpose sslserver -verify_ip ${IP} ${CRT}
    fi
}

if [ "$1" == "-h" ]; then
    echo "Set up the certificate of the issuer"
    echo "Usage: setup-cert.sh [IP] [HOSTNAME]"
    exit
fi

# IP setup
rm -f .config.ip
if [ "$1" == "" ]; then
    echo $(./resolve-ip.sh) > .config.ip
else
    echo $1 > .config.ip
fi
IP=$(cat .config.ip)

# Hostname setup
rm -f .config.hostname
if [ "$2" != "" ]; then
    HOSTNAME=$2
    LOCAL_ADDR=${HOSTNAME}
    echo "Using local hostname: ${LOCAL_ADDR}"
    echo ${LOCAL_ADDR} > .config.hostname
else
    HOSTNAME=
    LOCAL_ADDR=${IP}
fi
echo "Using local address: ${LOCAL_ADDR}"

generate_ssl_certificate
scripts/create-issuer-mdl-cert.sh ${LOCAL_ADDR}

install_certificates

echo
echo "mdoc certificate created, set the following options in app/app_config/config_countries.py:"
echo '"pid_mdoc_privkey": "/etc/eudiw/pid-issuer/privKey/'${LOCAL_ADDR}'.key"'
echo '"pid_mdoc_privkey_passwd": None'
echo '"pid_mdoc_cert": "/etc/eudiw/pid-issuer/cert/'${LOCAL_ADDR}'.crt.der"'
echo
