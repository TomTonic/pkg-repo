#!/usr/bin/env bash
# Builds a signed rpm repo (repodata/) from pools/rpm/<arch>/*.rpm.
# Only the repodata (repomd.xml) is signed, not individual rpms - see
# README.md for why. createrepo_c runs natively on the Ubuntu runner,
# no container needed.
set -euo pipefail

WORK="${1:?usage: build-rpm.sh <workdir> <sitedir>}"
SITE="${2:?usage: build-rpm.sh <workdir> <sitedir>}"

mkdir -p "$SITE/rpm"

shopt -s nullglob
cp "$WORK"/pools/rpm/x86_64/*.rpm "$SITE/rpm/" 2>/dev/null || true
cp "$WORK"/pools/rpm/aarch64/*.rpm "$SITE/rpm/" 2>/dev/null || true
shopt -u nullglob

createrepo_c "$SITE/rpm"
gpg --batch --yes --detach-sign --armor \
  -o "$SITE/rpm/repodata/repomd.xml.asc" "$SITE/rpm/repodata/repomd.xml"

cat >"$SITE/rpm/acmelab.repo" <<'EOF'
[acmelab]
name=acmelab package repository
baseurl=https://pkg.acmelab.de/rpm
enabled=1
gpgcheck=0
repo_gpgcheck=1
gpgkey=https://pkg.acmelab.de/pubkey.gpg
EOF
