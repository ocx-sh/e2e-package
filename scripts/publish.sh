#!/usr/bin/env bash
# Publish dist/ to ghcr.io/ocx-sh/e2e-package:<tag>.
#   publish.sh <tag> <mode> <sboms>
#   mode   keyless | key | none   (key reads OCX_SIGNING_KEY / OCX_KEY_PASSWORD from the environment)
#   sboms  0 | 1 | 2              (the second is attested minutes after the first)
# Needs GH_TOKEN in the environment; keyless needs the runner's id-token grant.
set -euo pipefail

tag=${1:?tag}
mode=${2:?mode}
sboms=${3:?sboms}
platform='linux/amd64+libc.glibc'
id="ghcr.io/ocx-sh/e2e-package:${tag}"
issuer='https://token.actions.githubusercontent.com'

export OCX_AUTH_ghcr_io_USER="${GITHUB_ACTOR:?}"
export OCX_AUTH_ghcr_io_TOKEN="${GH_TOKEN:?}"

push=(--identifier "$id" --platform "$platform"
  --annotation "org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}")
key=()
case "$mode" in
  keyless) push+=(--sign) ;;
  key)
    key=(--key env://OCX_SIGNING_KEY)
    push+=(--sign "${key[@]}")
    ;;
  none) ;;
  *) echo "unknown mode: $mode" >&2; exit 64 ;;
esac
if [ "$sboms" -ge 1 ]; then
  push+=(--sbom dist/sbom-1.json)
fi

ocx package push "${push[@]}" dist/e2e-package.tar.xz

# The platform manifest is signed by the push; sign the image index it landed in as well.
if [ "$mode" != none ]; then
  ocx package sign "${key[@]}" "$id"
fi

if [ "$sboms" -ge 2 ]; then
  sleep 180
  ocx package attest -p "$platform" --predicate dist/sbom-2.json --type cyclonedx "$id"
fi

case "$mode" in
  keyless)
    identity="${GITHUB_SERVER_URL}/${GITHUB_WORKFLOW_REF:?}"
    verify=(--certificate-identity "$identity" --certificate-oidc-issuer "$issuer")
    ;;
  key) verify=(--key keys/e2e-key.pub) ;;
  none) exit 0 ;;
esac
ocx package verify -p "$platform" "${verify[@]}" "$id"
ocx package verify "${verify[@]}" "$id"
if [ "$sboms" -ge 1 ] && [ "$mode" = keyless ]; then
  ocx package verify --attestation --type cyclonedx -p "$platform" "${verify[@]}" "$id"
fi
