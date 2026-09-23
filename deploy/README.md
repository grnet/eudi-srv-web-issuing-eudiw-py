# Deploying the issuer

One stack, three containers plus an init container: the PID issuer, the OIDC
authorization server, and the Postgres they need.

`docker-build.yml` publishes an image on push. `docker-deploy.yml` is manual
only, so merging a branch never changes what is running.

The deploy drives the box's Docker daemon over SSH. Nothing is copied to the
server: compose reads the file and the environment on the runner and sends the
daemon an already-expanded spec. Only containers, named volumes and the Docker
socket exist on the box.

## Two repositories, one stack

The OIDC server is built in `eudi-srv-issuer-oidc-py` and deployed from here.
The dependency runs one way, the issuer calls it for `/introspection` and
`/verify/user` and never the reverse, and the config naming both services lives
here. That repository has a build workflow and no `deploy/`.

## Before the first deploy

**The edge must be up.** nginx-proxy, acme-companion and `proxy-net` are defined
in `eudi-srv-wallet-provider`. The preflight step stops if `proxy-net` is
missing.

**Nothing else.** Document-signing material is unpacked into a named volume by
the `pki-init` container from archives that ship in the image, so there is no
out-of-band step on the box. That differs from the status list, whose signing key
is a CA-issued leaf that cannot be regenerated.

## Repository secrets

| Secret | What it is |
| --- | --- |
| `SSH_KEY` | Private key authorised for `ubuntu@3.69.83.252`. Written to `~/.ssh/eudiw-deploy` on the runner. Paste the whole file, BEGIN and END lines included. |
| `DATABASE_PASSWORD` | Postgres password for this stack. Generated, not reused. |
| `STATUSLIST_API_KEY` | `X-Api-Key` the issuer sends to the status list when allocating a revocation index. Must match that service's own `API_key`, currently `test`. |

Everything else is committed in `stack.env`, where it is reviewable in a diff.

Nothing keeps `STATUSLIST_API_KEY` in step with the status list's copy. Changing
one without the other means every credential issuance fails at the revocation
call.

## Routing

Every service shares `demo.eudiw.grnet.gr`, the only hostname that exists, and is
told apart by path:

| Path | Service |
| --- | --- |
| `/` | status list |
| `/wallet-provider/` | wallet provider |
| `/issuer/` | this issuer |
| `/auth/` | the OIDC server |

`VIRTUAL_DEST=/` strips the prefix, so both apps serve at their own root and are
unaware of it. The issuer rewrites its own published metadata at startup by
substituting `service_url` for the `credential_issuer` value baked into
`app/metadata_config/*.json`, so the prefix propagates without a code change.

### Discovery endpoints need a proxy rule

RFC 8414 §3.1 puts discovery metadata at the **host root** regardless of the
issuer's path: a client asking about `https://host/issuer` fetches
`https://host/.well-known/openid-credential-issuer/issuer`. On this hostname the
root belongs to the status list, so without a rule the wallet gets its 404.

The rule lives in `eudi-srv-wallet-provider`'s deploy compose, as an inline
config mounted at `/etc/nginx/vhost.d/demo.eudiw.grnet.gr`, because that stack
owns the proxy. It proxies to `<host>-<sha1 of VIRTUAL_PATH>`, which is how
nginx-proxy names a path-routed upstream.

Changing `ISSUER_PATH` or `OIDC_PATH` here means recomputing those hashes there:

    printf '%s' "/issuer/" | sha1sum

## The OIDC config

Upstream's `config.json` is 359 lines and almost all of it is fine as shipped.
Four values vary per deployment, so `render-oidc-config.py` reads the config out
of the image being deployed and merges `oidc-config.patch.json` over it. The
result is passed to compose as `OIDC_CONFIG_JSON` and mounted as a config.

`idpyoidc` expands `{domain}` itself, so setting `domain` also fixes
`server_name`, `op.server_info.issuer` and `webserver.domain`.

Worth knowing: `allowed_htu` is a DPoP allowlist. A token request whose URL is
not on it is rejected, so it has to name the token endpoint as the wallet sees
it, through the proxy and with the prefix.

## Internal and external URLs

The authorization server is reached two ways, and the config says so:

    base_url:     https://demo.eudiw.grnet.gr/auth   browser redirects, metadata
    internal_url: http://oidc:5000                   issuer to OIDC, in-network

Plain http on the internal one is not a shortcut. The OIDC server's `ssl_context`
is commented out upstream, so it serves http and nginx-proxy terminates TLS.
`app/route_oidc.py:297` prefers `internal_url` and falls back to `base_url`;
without it the issuer would dial its own public URL and go out through the proxy
and back.

## Postgres

Required at startup, not optional. `app/__init__.py:132` calls `init_db_status`
at import time, and the pool opens eagerly with upstream's own comment saying it
raises if the database is unreachable. It then creates three tables. This arrived
with the TS3 v1.5 work; older versions of this service had no database.

16.14-alpine, matching what `install.md` states the issuer was tested against.
Note the data mount is `/var/lib/postgresql/data`, correct up to 17; the wallet
provider runs 18, which changed that path.

## Deploying by hand

`workflow_dispatch` only registers once the workflow file is on the default
branch, so until this merges use `./deploy.sh` (untracked). It runs the same
compose commands against the same daemon.

    ./deploy.sh                      issuer at sha- of HEAD, newest built oidc
    ./deploy.sh <issuer-tag> <oidc-tag>

Both deployed services already use `sha-` tags rather than `latest` or a branch
tag, because a sha- tag names exactly one build and is published on every run.
`latest` is only published from a repository's default branch, and none of these
branches has merged there.

The OIDC tag cannot be derived from a commit in this repository, so `deploy.sh`
walks the sibling checkout's recent commits and picks the newest one that has a
published image. That is not always the branch tip: the build skips
markdown-only commits. The workflow has no sibling checkout, so it takes the tag
as a required input.

## Config changes need a recreate

Compose does not recreate a container when only a config's **content** changes.
It compares the service definition, and `content: ${VAR}` is textually the same
whatever `VAR` expands to. So a fix to `stack.env`, `config_issuer_backend.yaml.template`
or `oidc-config.patch.json` deploys without taking effect, and the container
keeps running with the old file. The deploy reports success.

    ./deploy.sh                      # image change
    RECREATE=1 ./deploy.sh           # config change

In the Deploy workflow, tick **Recreate containers even if the image tag is
unchanged**.

Cost a debugging cycle on the first deploy: the issuer kept crashing on a config
error that had already been fixed.

The wallet provider's stack is not affected the same way. Its inline configs hold
literal text, so editing one changes the service definition and compose recreates
on its own. Only `content: ${VAR}` hides the change.

## Still to sort

- The issuer frontend is not deployed. `FRONTEND_PUBLIC_URL` points at the EU
  reference instance until it is.
- Credentials are signed with EU reference test material (`PID-DS-0002`), not
  with a GRNET document signer. Switching means minting one from `WEBUILD/pki/`
  and mounting it instead of the unpacked archive.
- `dynamic_presentation_url`, `trust_validator` and `status_validator` still
  point at EU reference services.
