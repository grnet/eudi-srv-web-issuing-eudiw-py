#!/usr/bin/env python3
"""Rewrite the OIDC server's published metadata for this deployment.

The OIDC server answers /.well-known/openid-configuration and
/.well-known/oauth-authorization-server by sending /app/openid-configuration.json
as shipped (views.py, well_known). Nothing in config.json reaches it, so it
names upstream's https://dev.issuer.eudiw.dev/oidc as the issuer and every
endpoint: a wallet following it would be sent to the Commission's server.

This reads that file out of the image, substitutes the public URL for
upstream's, and prints the result for compose to mount over the original.

    ./deploy/render-oidc-metadata.py ghcr.io/grnet/eudi-srv-issuer-oidc-py:TAG https://host/issuer/oidc

Fails if any eudiw.dev URL survives, so an upstream change that adds a URL in
another form is caught at deploy rather than served.
"""
import json
import subprocess
import sys

UPSTREAM = "https://dev.issuer.eudiw.dev/oidc"


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    image, public_url = sys.argv[1], sys.argv[2].rstrip("/")

    shipped = subprocess.run(
        ["docker", "run", "--rm", "--entrypoint", "cat", image, "/app/openid-configuration.json"],
        capture_output=True, text=True, check=True,
    ).stdout

    rendered = json.loads(shipped.replace(UPSTREAM, public_url))

    left = [u for u in json.dumps(rendered).split('"') if "eudiw.dev" in u]
    if left:
        sys.exit(f"upstream URLs remain after substitution: {left}")
    if rendered.get("issuer") != public_url:
        sys.exit(f"issuer is {rendered.get('issuer')!r}, expected {public_url!r}")

    print(json.dumps(rendered, indent=2))


if __name__ == "__main__":
    main()
