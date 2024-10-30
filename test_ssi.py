import os
import json
import re
import jwt

from ssi_lib import SSI as _SSI
from ssi_lib import SSIIssuanceError, SSIGenerationError, SSIVerificationError

class SSI(_SSI):

    def __init__(self, confdir, tmpdir):
        self.confdir = confdir
        super().__init__(tmpdir)


    def _dump_json(self, data, filename):
        infile = os.path.join(self.tmpdir, filename)

        with open(infile, "w+") as f:
            json.dump(data, f)

        return infile


    def _dump_token(self, token, filename):
        infile = os.path.join(self.tmpdir, filename)

        with open(infile, "w+") as f:
            f.write(token)

        return infile


    def _read_token(self, filename, clean=False):
        infile = os.path.join(self.tmpdir, filename)

        with open(infile, "r") as f:
            token = f.read()

        if clean:
            os.remove(infile)

        return token


    def _decode_token(self, token):
        return jwt.decode(
            token, options={"verify_signature": False}
        )


    def _issue_credential(self, issuer_keypath, issuer_did, holder_did, outfile):
        res, code = self._run_cmd([
            "waltid-cli", "vc", "sign",
            "--key", issuer_keypath,
            "--issuer", issuer_did,
            "--subject", holder_did,
            "--overwrite",
            outfile
        ])
        return res, code


    def _verify_credential(self, vcfile, schema=None, allowed_issuer=None):
        command = ["waltid-cli", "vc", "verify"]
        args = ["-p", "signature", vcfile]

        if schema:
            args = ["-p", "schema", f"--arg=schema={schema}"] + args

        if allowed_issuer:
            args = ["-p", "allowed-issuer", f"--arg=issuer={allowed_issuer}"] + args

        # TODO: revoked_status_list goes here!

        command = command + args
        res, code = self._run_cmd(command)

        return res, code


    def _create_presentation(
        self,
        holder_keypath,
        holder_did,
        verifier_did,
        vcfile,
        vpfile,
        presentation_definition,
        presentation_submission_output,
        nonce=None
    ):
        res, code = self._run_cmd([
            "waltid-cli", "vp", "create",
            "-hk", holder_keypath,
            "-hd", holder_did,
            "-vd", verifier_did,
            "-vc", vcfile,
            "-vp", vpfile,
            "-pd", presentation_definition,
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


    def issue_credential(self, issuer_keypath, issuer_did, holder_did, content, clean=True):
        outfile = self._dump_json(content, "credential.json")

        res, code = self._issue_credential(
            issuer_keypath, issuer_did, holder_did, outfile
        )
        if not code == 0:
            raise SSIIssuanceError(res)

        token = self._read_token("credential.signed.json", clean=clean)
        credential = self._decode_token(token)

        if clean:
            os.remove(outfile)

        return credential, token


    def verify_credential(
        self,
        token,
        schema=None,
        allowed_issuer=None,
        clean=True
    ):
        vcfile = self._dump_token(token, "credential.signed.jwt")

        res, code = self._verify_credential(
            vcfile, schema=schema, allowed_issuer=allowed_issuer
        )

        if not code == 0:
            raise SSIVerificationError(res)

        if "ERROR" in res.upper():
            raise SSIVerificationError(res)

        if "FAIL" in res.upper():
            raise SSIVerificationError(res)

        if not "SUCCESS" in res.upper():
            raise SSIVerificationError("Invalid credential")

        credential = self._decode_token(token)

        if clean:
            os.remove(vcfile)

        return credential


    def create_presentation(
        self,
        holder_keypath,
        holder_did,
        verifier_did,
        credential_token,
        nonce=None,
        clean=True,
    ):
        vcfile = self._dump_token(credential_token, "credential.jwt")

        presentation_definition = os.path.join(
            self.confdir, "presentation-definition.json"
        )
        presentation_submission_output = os.path.join(
            self.confdir, "presentation-submission-output.json"
        )

        vpfile = os.path.join(self.tmpdir, "presentation.jwt")
        res, code = self._create_presentation(
            holder_keypath,
            holder_did,
            verifier_did,
            vcfile,
            vpfile,
            presentation_definition,
            presentation_submission_output,
            nonce=None
        )
        if not code == 0:
            raise SSIGenerationError(res)

        token = self._read_token("presentation.jwt")
        presentation = self._decode_token(token)

        if clean:
            os.remove(vcfile)
            os.remove(vpfile)

        return presentation, token


    def verify_presentation(self, holder_did, token, clean=True):
        vpfile = self._dump_token(token, "presentation.jwt")

        presentation_definition = os.path.join(
            self.confdir, "presentation-definition.json"
        )
        presentation_submission_output = os.path.join(
            self.confdir, "presentation-submission-output.json"
        )

        res, code = self._verify_presentation(
            holder_did,
            presentation_definition,
            presentation_submission_output,
            vpfile,
        )

        if not code == 0:
            raise SSIVerificationError(res)

        if "ERROR" in res.upper():
            raise SSIVerificationError(res)

        if "FAIL" in res.upper():
            raise SSIVerificationError(res)

        result = res.split("Overall: ")[1].split("\n")[0].upper()
        if not "SUCCESS" in result:
            raise SSIVerificationError("Invalid presentation")

        presentation = self._decode_token(token)

        if clean:
            os.remove(vpfile)

        return presentation


tmpdir = os.getenv("TMPDIR", "/home/dev/tmp")
confdir = os.getenv("CONFDIR", "/home/dev/config")
storage = "/home/dev/storage"   # TODO
ssi = SSI(confdir, tmpdir)

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
    issuer_keypath, issuer_did_id, holder_did_id, credential_content
)
assert pre_credential["iss"] == issuer_did_id
assert pre_credential["sub"] == holder_did_id
assert pre_credential["vc"] == credential_content
assert pre_credential == ssi._decode_token(pre_token)

verified = ssi.verify_credential(
    pre_token,
    allowed_issuer=issuer_did_id,
)
assert verified == pre_credential

pre_presentation, presentation_token = ssi.create_presentation(
    holder_keypath,
    holder_did_id,
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
credential = ssi._decode_token(token)

assert token == pre_token
assert credential == pre_credential

assert credential["iss"] == issuer_did_id
assert credential["sub"] == holder_did_id

