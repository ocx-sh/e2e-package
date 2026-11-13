#!/usr/bin/env bash
# Build the fixture binary, its CycloneDX SBOM and the ocx package bundle into dist/.
set -euo pipefail

platform='linux/amd64+libc.glibc'

cargo build --locked --release
rm -rf dist
mkdir -p dist/pkg/bin
cp target/release/e2e-package dist/pkg/bin/

ocx package exec ocx.sh/cyclonedx/cargo-cyclonedx:0.5.9 -- \
  cargo cyclonedx --format json --override-filename sbom
# Two SBOMs that differ, so a consumer can tell the newer one apart.
for n in 1 2; do
  jq --arg n "$n" '.metadata.properties = ((.metadata.properties // []) + [{"name": "e2e:sequence", "value": $n}])' \
    sbom.json >"dist/sbom-$n.json"
done

ocx package create dist/pkg -m metadata.json -o dist/e2e-package.tar.xz -p "$platform"
