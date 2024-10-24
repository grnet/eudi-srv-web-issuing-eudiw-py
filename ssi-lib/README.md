# ssi-lib

**SSI backend for EBSI-diplomas agents**

![Python >= 3.10](https://img.shields.io/badge/python-%3E%3D%203.10-blue.svg)

This library provides core SSI functionalities to the agents of EBSI-diplomas
invloved parties. These include key and DID generation, credential issuance,
credential verification and the capability of registering DIDs to the EBSI and
resolving them.

This is essentially a wrapper of the
[`waltid-ssikit`](https://github.com/walt-id/waltid-ssikit) command-line
toolkit.

## Install

The package can be simply installed with

```
python3 setup.py install 
```

However, in order to be able to actually use it, you must build
[`waltid-ssikit`](https://github.com/walt-id/waltid-ssikit)
and make the executables of the `./commands` folder globally 
available (e.g., by transfering them inside `/usr/local/sbin` 
on Debian based systems).

## Usage

```python
from ssi_lib import SSI

ssi = SSI('/home/user/tmp')
```

### Key generation

```python
jwks = ssi.generate_key("Ed25519", "/home/user/storage", "key.json")
```

## Documentation

## Development

### Tests
