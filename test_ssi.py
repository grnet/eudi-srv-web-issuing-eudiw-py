import os
import json
import re
import jwt

from ssi_lib import SSI as _SSI
from ssi_lib import SSIIssuanceError, SSIGenerationError, SSIVerificationError

class SSI(_SSI):

    def _issue_credential(self, keypath, holder_did, issuer_did, infile):
        # TODO: Improve script usage
        res, code = self._run_cmd([
            "issue-credential",
            "--key", keypath,
            "--issuer", issuer_did,
            "--holder", holder_did,
            "--export", infile,    # TDOD
        ])
        return res, code


    def _create_presentation(
        self,
        holder_did,
        holder_keypath,
        verifier_did,
        vcfile,
        presentation_definition,
        vpfile,
        presentation_submission_output,
        nonce=None
    ):
        # TODO: Improve script usage
        res, code = self._run_cmd([
            "present-credentials",
            "-hd", holder_did,
            "-hk", holder_keypath,
            "-vd", verifier_did,
            "-vc", vcfile,
            "-pd", presentation_definition,
            "-vp", vpfile,
            "-ps", presentation_submission_output,
        ])
        return res, code


    def _verify_presentation(
        self,
        holder_did,
        presentation_definition,
        presentation_submission_output,
        vpfile,
    ):
        res, code = self._run_cmd([
            "waltid-cli", "vp", "verify",
            "-hd", holder_did,
            "-pd", presentation_definition,
            "-ps", presentation_submission_output,
            "-vp", vpfile,
        ])
        return res, code


    def issue_credential(self, keypath, holder_did, issuer_did, content):
        infile = "/home/dev/tmp" + "/credential.json"  # TODO
        outfile = "/home/dev/tmp" + "/credential.signed.json"  # TODO

        with open(infile, "w+") as f:
            json.dump(content, f)

        res, code = self._issue_credential(
            keypath, holder_did, issuer_did, infile
        )
        if not code == 0:
            raise SSIIssuanceError(res)

        with open(outfile, "r") as f:
            token = f.read()

        credential = decode_credential_token(token)

        return credential, token


    def create_presentation(
        self,
        holder_did,
        holder_keypath,
        verifier_did,
        pre_token,
        nonce=None
    ):
        infile = "/home/dev/tmp" + "/credential.jwt"  # TODO
        outfile = "/home/dev/tmp" + "/presentation.jwt"  # TODO
        presentation_definition =  "/home/dev/config" + "/presentation-definition.json"
        presentation_submission_output = "/home/dev/config" + "/presentation-submission-output.json"

        with open(infile, "w+") as f:
            f.write(pre_token)

        res, code = self._create_presentation(
            holder_did,
            holder_keypath,
            verifier_did,
            infile,
            presentation_definition,
            outfile,
            presentation_submission_output,
            nonce=None
        )
        if not code == 0:
            raise SSIGenerationError(res)

        with open(outfile, "r") as f:
            token = f.read()

        presentation = decode_credential_token(token)
        return presentation, token


    def verify_presentation(
        self,
        holder_did,
        presentation_token,
    ):
        infile = "/home/dev/tmp" + "/presentation.jwt"  # TODO
        presentation_definition =  "/home/dev/config" + "/presentation-definition.json"
        presentation_submission_output = "/home/dev/config" + "/presentation-submission-output.json"

        with open(infile, "w+") as f:
            f.write(presentation_token)

        res, code = self._verify_presentation(
            holder_did,
            presentation_definition,
            presentation_submission_output,
            infile,
        )
        if not code == 0:
            raise SSIVerificationError(res)

        pattern = r"Success\s*\(([^()]*)\)"
        ans = res.split("\n")[0]
        matches = re.findall(pattern, ans)
        presentation = json.loads(matches[0])
        return presentation


ssi = SSI("/home/user/tmp")


storage = "/home/dev/storage"

holder_key = ssi.generate_key("Ed25519", storage, "holder_key.json")
holder_keypath = os.path.join(storage, "holder_key.json")
holder_did = ssi.generate_did(holder_keypath, storage, "holder_did.json")
holder_did_id = holder_did["content"]["id"]

issuer_key = ssi.generate_key("Ed25519", storage, "issuer_key.json")
issuer_keypath = os.path.join(storage, "issuer_key.json")
issuer_did = ssi.generate_did(issuer_keypath, storage, "issuer_did.json")
issuer_did_id = issuer_did["content"]["id"]

verifier_key = ssi.generate_key("Ed25519", storage, "verifier_key.json")
verifier_keypath = os.path.join(storage, "verifier_key.json")
verifier_did = ssi.generate_did(verifier_keypath, storage, "verifier_did.json")
verifier_did_id = verifier_did["content"]["id"]

def decode_credential_token(token):
    return jwt.decode(
        token, options={"verify_signature": False}
    )

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
pre_credential, pre_token = ssi.issue_credential(
    issuer_keypath, holder_did_id, issuer_did_id, credential_content
)
assert pre_credential["iss"] == issuer_did_id
assert pre_credential["sub"] == holder_did_id
assert pre_credential["vc"] == credential_content
assert pre_credential == decode_credential_token(pre_token)

pre_presentation, presentation_token = ssi.create_presentation(
    holder_did_id,
    holder_keypath,
    verifier_did_id,
    pre_token,
)

presentation = ssi.verify_presentation(
    holder_did_id,
    presentation_token,
)

assert presentation == pre_presentation

assert presentation["aud"] == verifier_did_id
assert presentation["iss"] == holder_did_id
assert presentation["sub"] == holder_did_id

token = presentation["vp"]["verifiableCredential"][0]    # could me more than one
credential = decode_credential_token(token)

assert token == pre_token
assert credential == pre_credential

assert credential["iss"] == issuer_did_id
assert credential["sub"] == holder_did_id

