#!/usr/bin/env bash
set -e

if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: ./create-issuer-mdl-cert.sh <DOMAIN> <PORT>"
    echo "Creates a certificate for mDL issuance"
    exit
fi

echo "== Creating key =="
KEY="$1.key"
openssl ecparam -name prime256v1 -genkey -noout -out ${KEY}

echo "== Creating certificate signing request =="
CSR="$1.csr"
rm -f ${CSR}
echo "[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
x509_extensions = v3_ca  # Section to use for cert extensions

[ req_distinguished_name ]
CN = $1
O = GRNET
C = GR

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
URI.1 = https://$1:$2
DNS.1 = $1

[ v3_ca ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = 1.0.18013.5.1.2
crlDistributionPoints = URI:http://83.212.72.114:8082/crl.pem
keyUsage = digitalSignature
subjectAltName = @alt_names
" > eudi-mdl-cert.conf

openssl req -new -sha256 -key ${KEY} \
	-subj "/CN=$1/O=GRNET/C=GR" \
	-out ${CSR}

echo "== Verifying the request =="
openssl req -in ${CSR} -noout -text

echo "== Generating the certificate =="
rm -f iaca.srl
CRT="$1.crt"
openssl x509 -req -in ${CSR} -CA iaca.pem -CAkey iaca.key -CAcreateserial -out ${CRT} -days 500 -sha256 -extfile eudi-mdl-cert.conf -extensions v3_ca
openssl x509 -in ${CRT} -noout -text
rm -f eudi-mdl-cert.conf

PUB_JWK="$1.jwk.pub.json"
JWK="$1.jwk.json"
step crypto jwk create ${PUB_JWK} ${JWK} --from-pem ${KEY} --insecure --no-password --force
DER="${CRT}.der"
openssl x509 -in ${CRT} -out ${DER} -outform DER

echo "== Files created =="
echo ${CRT}
echo ${DER}
echo ${KEY}
echo ${PUB_JWK}
echo ${JWK}

echo "== Sanity check =="
openssl x509 -inform der -in ${DER} -out sanity.crt.pem

openssl x509 -in sanity.crt.pem -pubkey -noout > sanity_cert_pubkey.pem
openssl pkey -in ${KEY} -pubout > sanity_key_pubkey.pem

diff sanity_cert_pubkey.pem sanity_key_pubkey.pem
echo "OK"
