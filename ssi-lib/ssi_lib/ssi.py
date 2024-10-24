import os
import json
import subprocess
from abc import ABCMeta, abstractmethod
from .types import Vc, Template


class SSIGenerationError(Exception):
    pass


class SSIRegistrationError(Exception):
    pass


class SSIResolutionError(Exception):
    pass


class SSIIssuanceError(Exception):
    pass


class SSIVerificationError(Exception):
    pass


class SSI(object):

    def __init__(self, tmpdir):
        self.tmpdir = tmpdir
        self.commands = {
            Vc.DIPLOMA: 'issue-diploma',
        }

    @staticmethod
    def _run_cmd(args):
        rslt = subprocess.run(args, stdout=subprocess.PIPE)
        resp = rslt.stdout.decode('utf-8').rstrip('\n')
        code = rslt.returncode
        return (resp, code)

    def _generate_key(self, algorithm, storage, outfile):
        res, code = self._run_cmd([
            'generate-key', '--algorithm', algorithm, '--storage', storage, '--export', outfile,
        ])
        return res, code

    # @abstractmethod
    # def _fetch_key(self, *args):
    #     """
    #     """

    def _load_key(self, *args):
        outfile = os.path.join(self.tmpdir, 'jwk.json')
        entry = self._fetch_key(*args)
        if entry:
            with open(outfile, 'w+') as f:
                json.dump(entry, f)
            res, code = self._run_cmd(['load-key', '--file', outfile, ])
            os.remove(outfile)
        else:
            res = 'No key found'
            code = 1
        return res, code

    def _generate_did(self, key, outfile):
        res, code = self._run_cmd([
            'generate-did', '--key', key, '--export', outfile,
        ])
        return res, code

    def _register_did(self, alias, token):
        token_file = os.path.join(self.tmpdir, 'bearer-token.txt')
        with open(token_file, 'w+') as f:
            f.write(token)
        res, code = self._run_cmd(['register-did', '--did', alias,
                                   '--token', token_file, '--resolve',
                                   ])
        os.remove(token_file)
        return res, code

    def _resolve_did(self, alias):
        res, code = self._run_cmd(['resolve-did', '--did', alias, ])
        return res, code

    def _resolve_template(self, vc_type):
        try:
            template = getattr(Template, vc_type)
        except AttributeError:
            err = 'Requested credential type does not exist: %s' % vc_type
            raise AttributeError(err)
        return template

    def _validate_vc_content(self, vc_type, content):
        template = self._resolve_template(vc_type)
        return template.keys() == content.keys()

    def _issue_vc(self, holder, issuer, vc_type, content, outfile):
        res, code = self._run_cmd([
            self.commands[vc_type],
            '--holder', holder,
            '--issuer', issuer,
            '--export', outfile,
            *content.values(),
        ])
        return res, code

    def _present_credentials(self, holder, credentials):
        args = ['present-credentials', '--holder', holder, ]
        for credential in credentials:
            args += ['-c', credential, ]
        res, code = self._run_cmd(args)
        return res, code

    def _extract_presentation_filename(self, buff):
        sep = 'Verifiable presentation was saved to file: '
        if not sep in buff:
            return None
        out = buff.split(sep)[-1].replace('"', '')
        return out

    def _verify_presentation(self, presentation):
        tmpfile = os.path.join(self.tmpdir, 'vp.json')
        with open(tmpfile, 'w+') as f:
            json.dump(presentation, f)
        res, code = self._run_cmd([
            'verify-credentials', '--presentation', tmpfile, ])
        os.remove(tmpfile)
        return res, code

    def _parse_verification_results(self, buff):
        aux = buff.split('Results: ', 1)[-1].replace(':', '').split(' ')
        out = {}
        for i in range(0, len(aux), 2):
            out[aux[i]] = {'true': True, 'false': False}[aux[i + 1]]
        return out

    def extract_alias_from_key(self, entry):
        return entry['kid']

    def extract_alias_from_did(self, entry):
        return entry['id']

    def extract_key_from_did(self, entry):
        return entry['verificationMethod'][0]['publicKeyJwk']['kid']

    def extract_alias_from_vc(self, entry):
        return entry['id']

    def extract_holder_from_vc(self, entry):
        return entry['credentialSubject']['id']

    def extract_alias_from_vp(self, entry):
        return entry['id']

    def extract_holder_from_vp(self, entry):
        return entry['holder']

    def generate_key(self, algorithm, storage, outfile):
        res, code = self._generate_key(algorithm, storage, outfile)
        if not code == 0:
            raise SSIGenerationError(res)
        with open(os.path.join(storage, outfile), 'r') as f:
            jwks = json.load(f)
        return jwks

    def generate_did(self, key, token, onboard=True, load_key=True):
        if load_key:
            # TODO: Investigate how necessary this step is
            # with respect to EBSI onboarding
            res, code = self._load_key(key)
            if code != 0:
                err = 'Could not load key: %s' % res
                raise SSIGenerationError(err)
        outfile = os.path.join(self.tmpdir, 'did.json')
        res, code = self._generate_did(key, outfile)
        if code != 0:
            raise SSIGenerationError(res)
        with open(outfile, 'r') as f:
            out = json.load(f)
        os.remove(outfile)
        return out

    def register_did(self, alias, token):
        if not token:
            err = 'No token provided'
            raise SSIRegistrationError(err)
        res, code = self._register_did(alias, token)
        if code != 0:
            raise SSIRegistrationError(res)

    def resolve_did(self, alias):
        res, code = self._resolve_did(alias)
        if code != 0:
            raise SSIResolutionError(res)

    def issue_credential(self, holder, issuer, vc_type, content):
        if not self._validate_vc_content(vc_type, content):
            err = 'Invalid credential content provided: %s' % err
            raise SSIIssuanceError(err)
        outfile = os.path.join(self.tmpdir, 'vc.json')
        res, code = self._issue_vc(holder, issuer, vc_type, content,
                                   outfile)
        if code != 0:
            raise SSIIssuanceError(res)
        with open(outfile, 'r') as f:
            out = json.load(f)
        os.remove(outfile)
        return out

    def generate_presentation(self, holder, credentials, waltdir):
        res, code = self._present_credentials(holder, credentials)
        if code != 0:
            raise SSIGenerationError(res)
        filename = self._extract_presentation_filename(res)
        if not filename:
            raise SSIGenerationError(res)
        outfile = os.path.join(waltdir, filename)
        with open(outfile, 'r') as f:
            out = json.load(f)
        os.remove(outfile)
        for tmpfile in credentials:
            os.remove(tmpfile)
        return out

    def verify_presentation(self, presentation):
        res, code = self._verify_presentation(presentation)
        if code != 0:
            raise SSIVerificationError(res)
        out = self._parse_verification_results(res)
        return out
