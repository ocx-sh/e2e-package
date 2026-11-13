# e2e-package

End-to-end test fixture for OCX package signing and publisher verification. Not a real package.

It publishes `ghcr.io/ocx-sh/e2e-package` under these tags, each signed differently. The
[`e2e-index`](https://github.com/ocx-sh/e2e-index) repository declares which signers each index root trusts.

| Tag | Workflow | Signed by | Attestation |
|---|---|---|---|
| `main` | `release.yml`, `case=main` | that workflow at `refs/heads/main` | one CycloneDX SBOM |
| `two-sboms` | `release.yml`, `case=two-sboms` | that workflow at `refs/heads/main` | two SBOMs, about three minutes apart |
| `tag` | `release-tag.yml`, on a `v*` tag push | that workflow at the tag ref | none |
| `other` | `other-signer.yml` | that workflow | one SBOM by that workflow |
| `key` | `key-sign.yml` | a key pair, no OIDC | none |
| `unsigned` | `unsigned.yml` | nothing | none |

Every workflow is manual (`workflow_dispatch`) except `release-tag.yml`, runs only from this repository
(guarded on its repository id) and, apart from the tag one, only from `main`. The signature covers the platform manifest
and the image index.

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
