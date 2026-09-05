#!/usr/bin/env bash
# Copies the static, non-generated parts (landing page, public keys) into
# the site directory alongside the generated apt/rpm/pacman/apk subtrees.
set -euo pipefail

SITE="${1:?usage: assemble-site.sh <sitedir>}"

mkdir -p "$SITE/alpine"
cp pubkey.gpg "$SITE/pubkey.gpg"
cp alpine/acmelab.rsa.pub "$SITE/alpine/acmelab.rsa.pub"
cp index.html "$SITE/index.html"
