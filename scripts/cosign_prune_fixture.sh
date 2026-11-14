#!/usr/bin/env bash
# Publish a throwaway candidate to the DEV package, sign and attest its platform manifest with cosign's TAG
# schema (`sha256-<hex>.sig`, `sha256-<hex>.att`), then prune the candidate and prove those tags went with it.
#   cosign_prune_fixture.sh
# Needs on PATH: the ocx under test, cosign, curl, jq. Env: GITHUB_ACTOR, GH_TOKEN, COSIGN_KEY (encrypted key PEM),
# COSIGN_PASSWORD. Only ghcr.io/ocx-sh/dev/e2e-package is touched, never the package the public e2e tests read.
set -euo pipefail

repo=ocx-sh/dev/e2e-package
package="ghcr.io/${repo}"
tag="0.0.0-dev_$(date -u +%Y%m%d%H%M%S)"
platform='linux/amd64+libc.glibc'
export OCX_AUTH_ghcr_io_USER="${GITHUB_ACTOR:?}"
export OCX_AUTH_ghcr_io_TOKEN="${GH_TOKEN:?}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

token="$(curl -fsS -u "${GITHUB_ACTOR}:${GH_TOKEN}" "https://ghcr.io/token?service=ghcr.io&scope=repository:${repo}:pull" | jq -er .token)"
api() { curl -fsS -H "Authorization: Bearer ${token}" "$@"; }
tags() { api "https://ghcr.io/v2/${repo}/tags/list?n=1000" | jq -r '.tags[]?' | sort; }

printf '#!/bin/sh\necho %s\n' "$tag" > "$work/bin"
echo "==> candidate $package:$tag"
"$here/publish_ocx_package.sh" --identifier "${package}:${tag}" --platform "$platform" --binary "$work/bin" --no-keep-tag

# The tag is an image index; the platform manifest is what ocx signs, and what cosign signs here.
index="$(api -H 'Accept: application/vnd.oci.image.index.v1+json' "https://ghcr.io/v2/${repo}/manifests/${tag}")"
digest="$(jq -er '.manifests[0].digest' <<<"$index")"
echo "==> platform manifest $digest"

cosign login ghcr.io -u "$GITHUB_ACTOR" --password-stdin <<<"$GH_TOKEN"
# `--new-bundle-format=false` is what makes cosign 3 write the `.sig` / `.att` tags instead of a referrer.
flags=(--key env://COSIGN_KEY --yes --new-bundle-format=false --use-signing-config=false)
cosign sign "${flags[@]}" "${package}@${digest}"
echo '{"fixture":"cosign-tagged"}' > "$work/predicate.json"
cosign attest "${flags[@]}" --type custom --predicate "$work/predicate.json" "${package}@${digest}"

hex="${digest#sha256:}"
tags > "$work/before.txt"
echo "==> tags before prune"; cat "$work/before.txt"
for want in "$tag" "sha256-${hex}.sig" "sha256-${hex}.att"; do
  grep -qxF "$want" "$work/before.txt" || { echo "::error::tag $want missing before the prune"; exit 1; }
done

# The dev package has no index, so --force. The dry run lists the selection before anything is deleted.
ocx package prune --forge github --force --dry-run --format json "$package" "$tag"
ocx package prune --forge github --force "$package" "$tag"

tags > "$work/after.txt"
echo "==> tags after prune"; cat "$work/after.txt"
for gone in "$tag" "sha256-${hex}.sig" "sha256-${hex}.att"; do
  ! grep -qxF "$gone" "$work/after.txt" || { echo "::error::tag $gone survived the prune"; exit 1; }
done
echo "==> removed from the tag list:"; comm -23 "$work/before.txt" "$work/after.txt"
