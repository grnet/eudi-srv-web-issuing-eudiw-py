#!/usr/bin/env sh
#
# Render the config template, then hand off to the app.
#
# The application's config loader (app/__init__.py:_load_config) reads
# ISSUER_CONFIG_PATH and yaml.safe_load()s it with no variable expansion. So the
# ${...} placeholders in the mounted template have to be substituted before the
# app ever sees the file. Doing it here keeps the app code untouched: the same
# image runs locally and on a server, with only the environment differing.
#
# envsubst is used rather than sed so an unset variable renders empty and fails
# loudly at startup, instead of silently leaving a literal "${VAR}" in a URL.

set -eu

TEMPLATE="${CONFIG_TEMPLATE:-/tmp/config.yaml.template}"
RENDERED="${ISSUER_CONFIG_PATH:-/config.yaml}"

if [ -f "$TEMPLATE" ]; then
    mkdir -p "$(dirname "$RENDERED")"
    envsubst < "$TEMPLATE" > "$RENDERED"

    # A leftover placeholder means a variable was missing from the environment.
    # Better to stop here than to serve metadata containing "${ISSUER_PUBLIC_URL}".
    # Comments are excluded so prose describing the templating cannot fail the run.
    if grep -v '^[[:space:]]*#' "$RENDERED" | grep -q '\${'; then
        echo "entrypoint: unsubstituted variables remain in $RENDERED:" >&2
        grep -vn '^[[:space:]]*#' "$RENDERED" | grep '\${' >&2
        exit 1
    fi
    echo "entrypoint: rendered $TEMPLATE -> $RENDERED"
else
    echo "entrypoint: no template at $TEMPLATE, using $RENDERED as-is"
fi

# ── Issuer metadata ─────────────────────────────────────────────────────────
#
# app/metadata_config/*.json hardcode the issuer's public URL in 22 places, and
# the app reads them from a fixed path next to the code (app/__init__.py:315),
# no env var, no template. On the VM, scripts/setup-issuer-metadata.sh handles
# this by `git restore` + `sed -i` over the tracked files, which dirties the
# working tree on every setup.
#
# Here the same substitution happens inside the container at start, against the
# image's own copy. The repo's files are never touched, so a developer's
# `git status` stays clean and the image is reusable across hostnames.
if [ -n "${ISSUER_HOST:-}" ]; then
    META_DIR="${ISSUER_METADATA_DIR:-/app/app/metadata_config}"
    if [ -d "$META_DIR" ]; then
        # The files reference two services on the same host, the issuer and the
        # authorization server, distinguished only by port. Replacing the host
        # and leaving the ports alone keeps both correct.
        sed -i -E "s#(https://)[A-Za-z0-9._-]+(:[0-9]+)#\1${ISSUER_HOST}\2#g" \
            "$META_DIR"/*.json
        echo "entrypoint: issuer metadata points at $ISSUER_HOST"
    fi
fi

# The log directory is a bind mount in dev and may arrive empty.
mkdir -p "$(dirname "${ISSUER_LOG_PATH:-/tmp/log_dev/logs.log}")"

exec "$@"
