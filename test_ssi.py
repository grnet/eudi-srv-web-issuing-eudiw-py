import os
import json
import re
import jwt

from ssi_lib import SSI as _SSI
from ssi_lib import SSIIssuanceError, SSIGenerationError, SSIVerificationError

class SSI(_SSI):

    def _issue_credential(self, keypath, holder_did, issuer_did, outfile):
        # TODO: Improve script usage
        res, code = self._run_cmd([
            "issue-credential",
            "--key", keypath,
            "--issuer", issuer_did,
            "--holder", holder_did,
            "--export", outfile,
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


    def issue_credential(self, keypath, holder_did, issuer_did, outfile):
        res, code = self._issue_credential(keypath, holder_did, issuer_did, outfile)
        if not code == 0:
            raise SSIIssuanceError(res)

        with open(outfile, "r") as f:
            credential = json.load(f)

        return credential


    def create_presentation(
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
        res, code = self._create_presentation(
            holder_did,
            holder_keypath,
            verifier_did,
            vcfile,
            presentation_definition,
            vpfile,
            presentation_submission_output,
            nonce=None
        )
        if not code == 0:
            raise SSIGenerationError(res)

        with open(vpfile, "r") as f:
            presentation = f.read()

        return presentation


    def verify_presentation(
        self,
        holder_did,
        presentation_definition,
        presentation_submission_output,
        vpfile,
    ):
        res, code = self._verify_presentation(
            holder_did,
            presentation_definition,
            presentation_submission_output,
            vpfile,
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


credential = ssi.issue_credential(
    issuer_keypath, holder_did_id, issuer_did_id, "/home/dev/app/claims.json",
)

presentation = ssi.create_presentation(
    holder_did_id,
    holder_keypath,
    verifier_did_id,
    "/home/dev/app/claims.signed.json",
    "/home/dev/app/presDef.json",
    "/home/dev/app/outputVp.jwt",
    "/home/dev/app/outputPresSub.json"
)

presentation = ssi.verify_presentation(
    holder_did_id,
    "/home/dev/app/presDef.json",
    "/home/dev/app/outputPresSub.json",
    "/home/dev/app/outputVp.jwt",
)

assert presentation["aud"] == verifier_did_id
assert presentation["iss"] == holder_did_id
assert presentation["sub"] == holder_did_id

token = presentation["vp"]["verifiableCredential"][0]    # could me more than one
credential = decoded_token = jwt.decode(
    token, options={"verify_signature": False}
)

assert credential["iss"] == issuer_did_id
assert credential["sub"] == holder_did_id
