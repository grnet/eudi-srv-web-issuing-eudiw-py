import os
from ssi_lib import SSI as _SSI

class SSI(_SSI):
    pass


ssi = SSI('/home/user/tmp') # TODO: Remove auxiliary tmp file


storage = "/home/dev/storage"

jwks = ssi.generate_key("Ed25519", storage, "key.json")
keypath = os.path.join(storage, "key.json")
did = ssi.generate_did(keypath, storage, "did.json")

print(jwks)
print(did)
