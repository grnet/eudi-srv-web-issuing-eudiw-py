#!/usr/bin/env bash
#
# This file demonstrates creation of IACA certificates. Notes:
#
# * This is not complete; a .crl distribution server should also
#   be set up (see "crlDistributionPoints" property below).
#
# * The generated certificate is self-signed.
#
# * For convenience, the generated certificate can also sign
#   SSL server certificates.
#

echo Creating root certificate...
openssl ecparam -name prime256v1 -genkey -noout -out iaca.key

echo '[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca # Section to use for cert extensions

[ req_distinguished_name ]
CN = PID Issuer CA - GR 01
O = GRNET
C = GR

[ v3_ca ]
basicConstraints = critical, CA:TRUE, pathlen:0
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = critical, 1.3.130.2.0.0.1.7, serverAuth, clientAuth, codeSigning, emailProtection
crlDistributionPoints = URI:http://83.212.72.114:8082/crl.pem
keyUsage = critical, keyCertSign, cRLSign, digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
' > eudi-cert.conf

IACA=iaca.pem
openssl req -new -key iaca.key -x509 -nodes -days 365 \
    -subj "/CN=PID Issuer CA - GR 01/O=GRNET/C=GR" \
    -out ${IACA} \
    -config eudi-cert.conf \
    -extensions v3_ca

openssl x509 -in ${IACA} -noout -text
echo "Created: ${IACA}"

# We check that this IACA can also be used to issue SSL server
# certificates (required key usages: https://www.ietf.org/rfc/rfc3280.txt, p.41)
echo "Checking validity for SSL server purposes"
openssl verify -CAfile iaca.pem -purpose sslserver ${IACA}
