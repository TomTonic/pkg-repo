#!/usr/bin/env bash
# Builds a signed apt repo (dists/stable/main) from pools/apt/<arch>/*.deb.
set -euo pipefail

WORK="${1:?usage: build-apt.sh <workdir> <sitedir>}"
SITE="${2:?usage: build-apt.sh <workdir> <sitedir>}"
# Resolve to absolute paths up front: the block below cd's around, and a
# relative $WORK would otherwise be looked up relative to the wrong dir.
WORK="$(cd "$WORK" && pwd)"
mkdir -p "$SITE"
SITE="$(cd "$SITE" && pwd)"

mkdir -p "$SITE/apt/pool" \
  "$SITE/apt/dists/stable/main/binary-amd64" \
  "$SITE/apt/dists/stable/main/binary-arm64"

shopt -s nullglob
cp "$WORK"/pools/apt/amd64/*.deb "$SITE/apt/pool/" 2>/dev/null || true
cp "$WORK"/pools/apt/arm64/*.deb "$SITE/apt/pool/" 2>/dev/null || true
shopt -u nullglob

cat >"$WORK/apt-ftparchive.conf" <<'EOF'
APT::FTPArchive::Release::Origin "tomtonic";
APT::FTPArchive::Release::Label "TomTonic package repository";
APT::FTPArchive::Release::Suite "stable";
APT::FTPArchive::Release::Codename "stable";
APT::FTPArchive::Release::Components "main";
APT::FTPArchive::Release::Architectures "amd64 arm64";
EOF

(
  cd "$SITE/apt"
  apt-ftparchive packages --arch amd64 pool >dists/stable/main/binary-amd64/Packages
  apt-ftparchive packages --arch arm64 pool >dists/stable/main/binary-arm64/Packages
  gzip -kf dists/stable/main/binary-amd64/Packages
  gzip -kf dists/stable/main/binary-arm64/Packages

  cd dists/stable
  apt-ftparchive -c "$WORK/apt-ftparchive.conf" release . >Release
  gpg --batch --yes --clearsign -o InRelease Release
  gpg --batch --yes -abs -o Release.gpg Release
)
