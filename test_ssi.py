import os
import json
import re
import jwt

import os
import json
import subprocess

from ssi_lib import SSI as _SSI
from ssi_lib import SSIIssuanceError, SSIGenerationError, SSIVerificationError

class SSI(_SSI):

    def __init__(self, vault, confdir, tmpdir):
        self.vault = vault
        self.confdir = confdir
        super().__init__(tmpdir)


    @staticmethod
    def _run_cmd(command):
        result = subprocess.run(command, stdout=subprocess.PIPE)

        res = result.stdout.decode("utf-8").rstrip("\n")
        code = result.returncode

        return res, code


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


    def _generate_key(self, algorithm, outfile):
        res, code = self._run_cmd([
            "waltid-cli", "key", "generate",
            "--keyType", algorithm,
            "--output", outfile,
        ])

        return res, code


    # TODO: Add EBSI option
    def _generate_did(self, keypath, outfile):
        res, code = self._run_cmd([
            "waltid-cli", "did", "create",
            "--key", keypath,
            "--did-doc-output", outfile,
        ])

        return res, code


    def _issue_credential(self, issuer_key, issuer_did, holder_did, outfile):
        res, code = self._run_cmd([
            "waltid-cli", "vc", "sign",
            "--key", issuer_key,
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
        holder_key,
        holder_did,
        verifier_did,
        vcfile,         # TODO: Allow more credentials
        vpfile,
        presentation_definition,
        presentation_submission_output,
        nonce=None
    ):
        res, code = self._run_cmd([
            "waltid-cli", "vp", "create",
            "-hk", holder_key,
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


    def generate_key(self, algorithm, filename):
        outfile = os.path.join(self.vault, filename)

        res, code = self._generate_key(algorithm, outfile)

        if not code == 0:
            raise SSIGenerationError(res)

        return outfile


    def generate_did(self, keypath, filename, get_full=False):
        outfile = os.path.join(self.vault, filename)

        res, code = self._generate_did(keypath, outfile)

        if not code == 0:
            raise SSIGenerationError(res)

        with open(os.path.join(outfile), "r") as f:
            did_obj = json.load(f)

        if get_full:
            return did_obj

        return did_obj["content"]["id"]


    def issue_credential(self, issuer_key, issuer_did, holder_did, content, clean=True):
        outfile = self._dump_json(content, "credential.json")

        res, code = self._issue_credential(
            issuer_key, issuer_did, holder_did, outfile
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
        holder_key,
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
            holder_key,
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


vault = os.getenv("VAULT", "home/dev/vault")
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
retrieved = ssi.verify_credential(credential_token,allowed_issuer=issuer_did)
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

