#!/usr/bin/env bash
#
# Lay out the mdoc document-signing material the issuer needs at runtime.
#
# This is NOT the TLS chain. Two separate PKIs are in play and conflating them is
# the classic mistake here:
#
#   TLS               who the server is on the wire.   dev CA (bootstrap.sh).
#   Document signing  who signed the credential.       IACA + PID-DS, below.
#
# Everything here comes from the EU reference test PKI already committed under
# api_docs/test_tokens/, test material, valid only against test wallets. No
# real key is created, copied, or needed.
#
# Output goes to out/eudiw/, which compose mounts at /etc/eudiw/pid-issuer-dev/.
# That path is what config/issuer.dev.yaml points at.

set -euo pipefail

cd "$(dirname "$0")"
REPO=".."
OUT="out/eudiw"
CERT_DIR="$OUT/cert"
PRIVKEY_DIR="$OUT/privKey"

# The reference stack ships several document signers. PID-DS-0002 is the one the
# committed config already refers to, so match it rather than inventing a choice.
DS="PID-DS-0002"

mkdir -p "$CERT_DIR" "$PRIVKEY_DIR"

echo "==> Unpacking document signer $DS"
# The zip holds <DS>.cert.der and <DS>.pid-ds-0002.key.pem.
unzip -o -q "$REPO/api_docs/test_tokens/DS-token/$DS.zip" -d "$PRIVKEY_DIR"
mv -f "$PRIVKEY_DIR/$DS.cert.der" "$CERT_DIR/"

# The config names country-specific files (EU, UT). Both point at the same test
# signer in the reference setup, so link the one we unpacked into both names
# rather than shipping duplicate copies.
DS_KEY="$(find "$PRIVKEY_DIR" -maxdepth 1 -name "$DS*.key.pem" -print -quit)"
for country in EU UT; do
  cp -f "$DS_KEY"              "$PRIVKEY_DIR/${DS}_${country}.pem"
  cp -f "$CERT_DIR/$DS.cert.der" "$CERT_DIR/${DS}_${country}_cert.der"
done

echo "==> Installing IACA root"
gunzip -c "$REPO/api_docs/test_tokens/IACA-token/PIDIssuerCAUT01.pem.gz" \
  > "$CERT_DIR/PIDIssuerCAUT01.pem"

# The nonce endpoint signs with this; the credential request endpoint decrypts
# with the other. Both are generated, not shipped, they are per-deployment.
# The filename must match keys.nonce_path in config/issuer.dev.yaml.
echo "==> Generating nonce + credential-request keys"
[[ -f "$PRIVKEY_DIR/private_nonce_key.pem" ]] \
  || openssl genrsa -out "$PRIVKEY_DIR/private_nonce_key.pem" 4096 2>/dev/null
# Must be P-256 EC: _build_credential_encryption_metadata() rejects anything else
# ("credential_encryption_key must be a P-256 EC private key"). The public JWK
# advertised in the issuer metadata is derived from it.
[[ -f "$PRIVKEY_DIR/credential_request.pem" ]] \
  || openssl ecparam -name prime256v1 -genkey -noout \
       -out "$PRIVKEY_DIR/credential_request.pem" 2>/dev/null

chmod 644 "$PRIVKEY_DIR"/* "$CERT_DIR"/*

echo
echo "Done. Document-signing material is in pki/$OUT/"
echo "  certs: $(ls "$CERT_DIR" | tr '\n' ' ')"
