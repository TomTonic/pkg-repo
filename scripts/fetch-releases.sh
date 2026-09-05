#!/usr/bin/env bash
# Reads manifest.json, downloads each listed tool's latest + previous
# non-draft/non-prerelease GitHub release assets into per-format,
# per-architecture pools. Fully stateless - nothing persisted between runs.
set -euo pipefail

WORK="${1:?usage: fetch-releases.sh <workdir>}"

mkdir -p \
  "$WORK/pools/apt/amd64" "$WORK/pools/apt/arm64" \
  "$WORK/pools/rpm/x86_64" "$WORK/pools/rpm/aarch64" \
  "$WORK/pools/pacman/x86_64" "$WORK/pools/pacman/aarch64" \
  "$WORK/pools/apk/x86_64" "$WORK/pools/apk/aarch64"

jq -c '.tools[]' manifest.json | while read -r tool; do
  repo=$(jq -r '.repo' <<<"$tool")
  package=$(jq -r '.package' <<<"$tool")
  echo "== $repo ($package) =="

  releases=$(gh api "repos/$repo/releases" --paginate \
    --jq '[.[] | select(.draft==false and .prerelease==false)] | sort_by(.published_at) | reverse | .[0:2]')

  echo "$releases" | jq -c '.[]' | while read -r release; do
    tag=$(jq -r '.tag_name' <<<"$release")
    version="${tag#v}"
    echo "  release $tag (version $version)"

    jq -c '.assets[]' <<<"$release" | while read -r asset; do
      name=$(jq -r '.name' <<<"$asset")
      url=$(jq -r '.browser_download_url' <<<"$asset")

      case "$name" in
      *.deb)
        arch=""
        [[ "$name" == *amd64* ]] && arch=amd64
        [[ "$name" == *arm64* ]] && arch=arm64
        [[ -z "$arch" ]] && continue
        echo "    -> apt/$arch/$name"
        curl -fsSL -o "$WORK/pools/apt/$arch/$name" "$url"
        ;;
      *.rpm)
        arch=""
        [[ "$name" == *x86_64* ]] && arch=x86_64
        [[ "$name" == *aarch64* ]] && arch=aarch64
        [[ -z "$arch" ]] && continue
        echo "    -> rpm/$arch/$name"
        curl -fsSL -o "$WORK/pools/rpm/$arch/$name" "$url"
        ;;
      *.pkg.tar.zst)
        arch=""
        [[ "$name" == *x86_64* ]] && arch=x86_64
        [[ "$name" == *aarch64* ]] && arch=aarch64
        [[ -z "$arch" ]] && continue
        echo "    -> pacman/$arch/$name"
        curl -fsSL -o "$WORK/pools/pacman/$arch/$name" "$url"
        ;;
      *.apk)
        arch=""
        [[ "$name" == *x86_64* ]] && arch=x86_64
        [[ "$name" == *aarch64* ]] && arch=aarch64
        [[ -z "$arch" ]] && continue
        # Alpine requires the exact filename "<package>-<version>.apk"
        # (no arch suffix - files already live in a per-arch directory);
        # nfpm's own output name doesn't match that, so it gets renamed here.
        echo "    -> apk/$arch/$package-$version.apk (renamed from $name)"
        curl -fsSL -o "$WORK/pools/apk/$arch/$package-$version.apk" "$url"
        ;;
      esac
    done
  done
done
