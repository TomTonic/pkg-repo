#!/usr/bin/env bash
# Builds a signed apk (Alpine) index from pools/apk/<arch>/*.apk.
# apk-tools/abuild aren't packaged for Ubuntu, so this runs inside an
# alpine:latest container instead. Only the index is signed, not
# individual packages - that's Alpine's own native convention, not a
# simplification we made.
set -euo pipefail

WORK="${1:?usage: build-apk.sh <workdir> <sitedir> <alpine-rsa-private-key-file>}"
SITE="${2:?usage: build-apk.sh <workdir> <sitedir> <alpine-rsa-private-key-file>}"
RSA_KEY_FILE="${3:?usage: build-apk.sh <workdir> <sitedir> <alpine-rsa-private-key-file>}"

mkdir -p "$SITE/apk/x86_64" "$SITE/apk/aarch64"

shopt -s nullglob
cp "$WORK"/pools/apk/x86_64/*.apk "$SITE/apk/x86_64/" 2>/dev/null || true
cp "$WORK"/pools/apk/aarch64/*.apk "$SITE/apk/aarch64/" 2>/dev/null || true
shopt -u nullglob

docker rm -f apk-build >/dev/null 2>&1 || true
docker run -d --name apk-build alpine:latest sleep infinity
docker cp "$SITE/apk" apk-build:/work-apk
docker cp "$RSA_KEY_FILE" apk-build:/acmelab.rsa

docker exec apk-build sh -c '
set -e
apk add --no-cache abuild >/dev/null

for dir in /work-apk/*/; do
  cd "$dir"
  set -- *.apk
  [ "$1" = "*.apk" ] && continue
  # --allow-untrusted: we deliberately do not sign individual .apk files,
  # only the index below (same reasoning as the rpm repodata signature).
  apk index --allow-untrusted -o APKINDEX.tar.gz -- *.apk
  abuild-sign -k /acmelab.rsa APKINDEX.tar.gz
done
'

docker cp apk-build:/work-apk/. "$SITE/apk/"
docker rm -f apk-build >/dev/null 2>&1
