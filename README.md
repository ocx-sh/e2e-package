# e2e-package

End-to-end test fixture for OCX package signing and publisher verification. Not a real package.

It publishes `ghcr.io/ocx-sh/e2e-package` under these tags, each signed differently. The
[`e2e-index`](https://github.com/ocx-sh/e2e-index) repository declares which signers each index root trusts.

| Tag | Workflow | Signed by | Attestation |
|---|---|---|---|
| `main` | `release.yml` as it was before the release pipeline (published once) | `release.yml` at `refs/heads/main` | one CycloneDX SBOM |
| `two-sboms` | the same, published once | `release.yml` at `refs/heads/main` | two SBOMs, about three minutes apart |
| `tag` | `release-tag.yml`, on a `v*` tag push | that workflow at the tag ref | none |
| `other` | `other-signer.yml` | that workflow | one SBOM by that workflow |
| `key` | `key-sign.yml` | a key pair, no OIDC | none |
| `unsigned` | `unsigned.yml` | nothing | none |
| `0.0.1` | `unsigned-v.yml` | nothing, until `backfill.yml` runs | none, until `backfill.yml` runs |
| `0.1.0`, `0.1`, `0`, `latest` | `release.yml`, `mode=release` | that workflow at `refs/heads/main` | one SBOM per platform |
| `0.1.0-rcN` | `release.yml`, `mode=candidate` | that workflow at `refs/heads/main` | one SBOM per platform |
| `0.1.0-dev_<UTC>` (in `ghcr.io/ocx-sh/dev/e2e-package`) | `release.yml`, `mode=dev` | that workflow at the dispatched ref | one SBOM per platform |

`release.yml` and `backfill.yml` are copies of the ocx repository's release pipeline (see the comment at the top of
each for how they differ). They build ocx from `ocx_repository` at `ocx_ref` and drive the registry with it; `release.yml`
builds the fixture on `ubuntu-24.04` and `ubuntu-24.04-arm` (`linux/amd64`, `linux/arm64`, both glibc) and announces
with `--output`, uploading the index entry as the `index-out` artifact. Nothing is written to a repository: the entry
is committed to e2e-index by hand. `backfill.yml` signs and attests `0.0.1` (`tags=v0.0.1`) and runs in the
`release-backfill` environment.

Every workflow is manual (`workflow_dispatch`) except `release-tag.yml`, runs only from this repository
(guarded on its repository id) and, apart from the tag one, only from `main`. The signature covers the platform manifest,
which is what an install verifies; the image index is not signed.

## Testing by hand

The commands and the expected result of every tag are in
[e2e-index TESTING.md](https://github.com/ocx-sh/e2e-index/blob/main/TESTING.md).

## Required secrets and settings

Names only; no value belongs in this repository.

- Secrets: `E2E_SIGNING_KEY` (cosign encrypted key PEM) and `E2E_SIGNING_KEY_PASSWORD`, both read by `key-sign.yml` only.
  The matching public key is `keys/e2e-key.pub`.
- Repository setting: Actions workflow permissions must allow the job-level `id-token: write` and `packages: write`
  grants the workflows ask for.
- GHCR package `e2e-package`: after the first `release.yml` run, link it to this repository, grant this repository
  Actions access and make it public, so the other workflows can push and anonymous clients can pull.

## Local build

`scripts/build.sh` and `scripts/publish.sh` are what the workflows run; they need `ocx`, `cargo` and `jq`.
