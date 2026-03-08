# GitHub Public Distribution Hardening

## Goal

Use a public GitHub repository for source code, issues, pull requests, CI, and public release discovery without exposing release credentials or making signed release publication too easy to abuse.

## Recommended operating model

- Keep source code and standard CI in the public repository.
- Keep signing, notarization, and Sparkle signing secrets in the GitHub environment `production-release`.
- Require human approval on the `production-release` environment before every signed release job.
- Trigger signed releases manually with `workflow_dispatch`.
- Protect the `main` branch and the `v*` tag namespace in GitHub settings.
- Publish Sparkle archives and `appcast.xml` to external static hosting, even if GitHub Releases also carry the same artifacts.

## Why this split matters

Public repositories make workflow definitions, commit history, and Actions logs visible to everyone. That is fine for source code, but it means the release pipeline has to be treated like a production deployment path.

The hardening in this repository assumes:

- No repository-level release secrets
- No automatic release on tag push
- No long-lived Sparkle private key file inside the build artifacts directory
- No unsigned or unreviewed path to a notarized release

## GitHub settings to enable

### Environments

Create `production-release` and configure:

- Required reviewers: enabled
- Deployment branches: `main` only
- Environment secrets:
  - `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`
  - `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`
  - `APPLE_TEAM_ID`
  - `APPLE_ID`
  - `APPLE_APP_SPECIFIC_PASSWORD`
  - `APPLE_NOTARY_TEAM_ID`
  - `KEYCHAIN_PASSWORD`
  - `SPARKLE_FEED_URL`
  - `SPARKLE_PUBLIC_ED_KEY`
  - `SPARKLE_PRIVATE_KEY`
  - `SPARKLE_DOWNLOAD_BASE_URL`

### Branch and tag protection

- Protect `main`
- Require pull requests for `main`
- Restrict who can push matching tags for `v*`
- Limit write access to trusted maintainers only

### Security features

- Enable Dependabot alerts
- Enable secret scanning
- Enable private vulnerability reporting
- Add a security contact in `SECURITY.md`

## Release flow

1. Merge reviewed code into `main`.
2. Open the `Release` workflow and provide a semver tag like `v0.1.0`.
3. Approve the `production-release` environment when prompted.
4. Let GitHub Actions build, sign, notarize, and publish the release artifacts.
5. Sync the generated `appcast.xml` and archives to the public update host used by Sparkle.

## Residual risks

- A maintainer with write access and environment approval rights can still ship a malicious release.
- Public Actions logs may still expose operational detail if future steps print sensitive paths or metadata.
- Sparkle private key compromise remains high impact; treat it like a production signing key and rotate it if you suspect exposure.

## Operational advice

- Re-run signed releases only from reviewed commits on `main`.
- Keep release approvals to a small set of maintainers.
- Prefer rotating Apple and Sparkle credentials after team changes.
- Audit workflow changes in pull requests with the same care as application code.
