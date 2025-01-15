import os

from ssi_lib import (
    SSI,
    SSIGenerationError,
    SSIIssuanceError,
    SSIVerificationError,
)


vault = os.getenv("VAULT", "/home/dev/vault")
confdir = os.getenv("CONFDIR", "/home/dev/config")
tmpdir = os.getenv("TMPDIR", "/home/dev/tmp")

ssi = SSI(vault, confdir, tmpdir)


holder_key = ssi.generate_key("Ed25519", "holder_key.json")
holder_did = ssi.generate_did(holder_key, "holder_did.json")

issuer_key = ssi.generate_key("Ed25519", "issuer_key.json")
issuer_did = ssi.generate_did(issuer_key, "issuer_did.json")

verifier_key = ssi.generate_key("Ed25519", "verifier_key.json")
verifier_did = ssi.generate_did(verifier_key, "verifier_did.json")


credential_content = {
  "@context": [
    "https://www.w3.org/ns/credentials/v2",
    "https://www.w3.org/ns/credentials/examples/v2"
  ],
  "id": "http://university.example/credentials/58473",
  "type": ["VerifiableCredential", "ExampleAlumniCredential"],
  "issuer": "did:example:2g55q912ec3476eba2l9812ecbfe",
  "validFrom": "2010-01-01T00:00:00Z",
  "credentialSubject": {
    "id": "did:example:ebfeb1f712ebc6f1c276e12ec21",
    "alumniOf": {
      "id": "did:example:c276e12ec21ebfeb1f712ebc6f1",
      "name": "Example University"
    }
  }
}


# Credential issuance
credential, credential_token = ssi.issue_credential(
    issuer_key, issuer_did, holder_did, credential_content
)
assert credential["iss"] == issuer_did
assert credential["sub"] == holder_did
assert credential["vc"] == credential_content


# Credential verification
retrieved = ssi.verify_credential(credential_token, allowed_issuer=issuer_did)
assert retrieved == credential


# Presentation creation
presentation, presentation_token = ssi.create_presentation(
    holder_key, holder_did, verifier_did, credential_token,
)
assert presentation["aud"] == verifier_did
assert presentation["iss"] == holder_did
assert presentation["sub"] == holder_did


# Presentation verification
retrieved_presentation = ssi.verify_presentation(holder_did, presentation_token)
assert retrieved_presentation == presentation


# Overall compatibility checks
embedded_token = presentation["vp"]["verifiableCredential"][0]    # could me more than one
assert embedded_token == credential_token
embedded_credential = ssi._decode_token(embedded_token)
assert embedded_credential == credential
assert embedded_credential["iss"] == issuer_did
assert embedded_credential["sub"] == holder_did
