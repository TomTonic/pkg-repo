#!/usr/bin/env bash
# Builds a signed pacman repo db from pools/pacman/<arch>/*.pkg.tar.zst.
# pacman-contrib (repo-add) isn't packaged for Ubuntu, so this runs inside
# an archlinux:base container instead.
set -euo pipefail

WORK="${1:?usage: build-pacman.sh <workdir> <sitedir> <gpg-private-key-file>}"
SITE="${2:?usage: build-pacman.sh <workdir> <sitedir> <gpg-private-key-file>}"
GPG_KEY_FILE="${3:?usage: build-pacman.sh <workdir> <sitedir> <gpg-private-key-file>}"

mkdir -p "$SITE/pacman/x86_64" "$SITE/pacman/aarch64"

shopt -s nullglob
cp "$WORK"/pools/pacman/x86_64/*.pkg.tar.zst "$SITE/pacman/x86_64/" 2>/dev/null || true
cp "$WORK"/pools/pacman/aarch64/*.pkg.tar.zst "$SITE/pacman/aarch64/" 2>/dev/null || true
shopt -u nullglob

docker rm -f pacman-build >/dev/null 2>&1 || true
docker run -d --name pacman-build archlinux:base sleep infinity
docker cp "$SITE/pacman" pacman-build:/work-pacman
docker cp "$GPG_KEY_FILE" pacman-build:/private-key.asc

docker exec pacman-build bash -c '
set -e
# DisableSandbox works around a seccomp incompatibility seen when this
# runs emulated (e.g. qemu-user on an arm64 host); harmless natively.
sed -i "/^\[options\]/a DisableSandbox" /etc/pacman.conf
pacman -Sy --noconfirm pacman-contrib gnupg >/dev/null

export GNUPGHOME=/root/.gnupg
mkdir -p "$GNUPGHOME" && chmod 700 "$GNUPGHOME"
gpg --batch --import /private-key.asc >/dev/null 2>&1

shopt -s nullglob
for dir in /work-pacman/*/; do
  cd "$dir"
  pkgs=(*.pkg.tar.zst)
  [ ${#pkgs[@]} -eq 0 ] && continue
  repo-add tomtonic.db.tar.zst "${pkgs[@]}"
  gpg --batch --yes --detach-sign tomtonic.db.tar.zst
  # pacman fetches "<reponame>.db.sig", not "<reponame>.db.tar.zst.sig"
  ln -sf tomtonic.db.tar.zst.sig tomtonic.db.sig
done
'

docker cp pacman-build:/work-pacman/. "$SITE/pacman/"
docker rm -f pacman-build >/dev/null 2>&1
