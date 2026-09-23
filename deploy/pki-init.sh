#!/usr/bin/env sh
#
# Lay out the issuer's document-signing material into /etc/eudiw/pid-issuer-dev,
# which the deploy stack mounts as a named volume.
#
# Safe to run on every deploy. It unpacks material that ships in the image and
# generates two keys only if they are absent, so repeated runs produce the same
# result. That is what makes it usable as an init container, unlike the WeBuild
# scripts in interop_event_tools, which mint a new CA on every run and must stay
# a deliberate ceremony.
#
# Everything here is EU reference *test* material published with the reference
# implementation, except the two generated keys, which are per-deployment.
set -eu

OUT="${PKI_OUT:-/etc/eudiw/pid-issuer-dev}"
CERT_DIR="$OUT/cert"
PRIVKEY_DIR="$OUT/privKey"
TOKENS="${TEST_TOKENS:-/app/api_docs/test_tokens}"

# The reference stack ships several document signers. PID-DS-0002 is the one
# upstream's config already names.
DS="PID-DS-0002"
DS_PASSWORD="pid-ds-0002"

mkdir -p "$CERT_DIR" "$PRIVKEY_DIR"

if [ -f "$CERT_DIR/${DS}_EU_cert.der" ]; then
    echo "pki-init: document signer already unpacked"
else
    echo "pki-init: unpacking $DS"
    # The zip holds <DS>.cert.der and <DS>.pid-ds-0002.key.pem. Python's zipfile
    # rather than unzip, which the slim runtime image does not carry.
    python3 -m zipfile -e "$TOKENS/DS-token/$DS.zip" "$PRIVKEY_DIR"
    mv -f "$PRIVKEY_DIR/$DS.cert.der" "$CERT_DIR/"

    # The shipped key is an encrypted PKCS#8 blob whose password is its own
    # friendlyName. The app hands the configured password straight to
    # load_pem_private_key(), which wants bytes rather than the string YAML
    # gives it, so an encrypted key cannot be used as-is. Decrypting here keeps
    # metadata_signing_key_password null.
    DS_KEY=$(find "$PRIVKEY_DIR" -maxdepth 1 -name "$DS*.key.pem" -print | head -1)
    openssl pkey -in "$DS_KEY" -passin "pass:$DS_PASSWORD" \
        -out "$PRIVKEY_DIR/$DS.decrypted.pem"

    # The signed-metadata path loads the certificate as PEM, the mdoc signing
    # path reads DER. Keep both.
    openssl x509 -inform der -in "$CERT_DIR/$DS.cert.der" -out "$CERT_DIR/$DS.cert.pem"

    # The config names country-specific files. All point at the same test signer
    # in the reference setup.
    for country in EE EU PT UT; do
        cp -f "$PRIVKEY_DIR/$DS.decrypted.pem" "$PRIVKEY_DIR/${DS}_${country}.pem"
        cp -f "$CERT_DIR/$DS.cert.der"         "$CERT_DIR/${DS}_${country}_cert.der"
        cp -f "$CERT_DIR/$DS.cert.pem"         "$CERT_DIR/${DS}_${country}_cert.pem"
    done
    rm -f "$PRIVKEY_DIR/$DS.decrypted.pem"

    gunzip -c "$TOKENS/IACA-token/PIDIssuerCAUT01.pem.gz" > "$CERT_DIR/PIDIssuerCAUT01.pem"
fi

# Generated, not shipped: these are per-deployment and must survive a redeploy,
# which is why the volume is named rather than anonymous. Regenerating the
# credential-request key changes the public JWK advertised in the issuer
# metadata.
if [ ! -f "$PRIVKEY_DIR/nonce_rsa2048.pem" ]; then
    echo "pki-init: generating nonce key"
    openssl genrsa -out "$PRIVKEY_DIR/nonce_rsa2048.pem" 2048
fi

# Must be P-256: _build_credential_encryption_metadata() rejects anything else.
if [ ! -f "$PRIVKEY_DIR/credential_request.pem" ]; then
    echo "pki-init: generating credential-request key"
    openssl ecparam -name prime256v1 -genkey -noout -out "$PRIVKEY_DIR/credential_request.pem"
fi

chmod 644 "$PRIVKEY_DIR"/* "$CERT_DIR"/*
echo "pki-init: ready"
ls "$CERT_DIR" | sed 's/^/  cert\//'
ls "$PRIVKEY_DIR" | sed 's/^/  privKey\//'
