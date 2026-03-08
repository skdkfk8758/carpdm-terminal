# GitHub Private Distribution

## Goal

Use a private GitHub repository as the system of record for source code, pull requests, issue tracking, CI, and internal alpha releases, while keeping the release pipeline compatible with notarized direct-download macOS distribution and Sparkle updates.

## Recommended operating model

- Source code stays in a private GitHub repository.
- Pull requests, issues, and CI run in the same private repository.
- GitHub Actions produces a signed, notarized ZIP artifact plus Sparkle metadata.
- GitHub Releases can be used for internal testers who already have repository access.
- Sparkle appcast and downloadable archives should be published to external static hosting for end-user auto-update.

This split matters because private GitHub release assets require authenticated access. That is acceptable for internal collaborators, but it is a poor fit for a consumer-style auto-update feed.

## Repository files added for this

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `scripts/release/import_certificate.sh`
- `scripts/release/build_archive.sh`
- `scripts/release/notarize.sh`
- `scripts/release/generate_appcast.sh`
- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`
- `Config/Secrets.example.xcconfig`

## Required GitHub environment secrets

Create a GitHub environment named `production-release` and store the release secrets there instead of repository-level secrets. This keeps signing material behind required reviewers and prevents the release workflow from receiving the values until a reviewer approves the job.

### Apple signing and notarization

- `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`
- `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_NOTARY_TEAM_ID`
- `KEYCHAIN_PASSWORD`

### Sparkle

- `SPARKLE_FEED_URL`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_PRIVATE_KEY`
- `SPARKLE_DOWNLOAD_BASE_URL`

The release workflow writes `Config/Secrets.xcconfig` from `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY` so the built app embeds `SUFeedURL` and `SUPublicEDKey`.

Recommended environment settings:

- Required reviewers enabled
- Deployment branches restricted to `main`
- Protected tag pattern `v*`
- Manual `workflow_dispatch` releases only

## Local setup

1. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig`.
2. Fill in `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY`.
3. Install full Xcode and XcodeGen.
4. Run `xcodegen generate`.
5. Build locally or let GitHub Actions create notarized artifacts.
6. Configure the `production-release` environment before attempting the release workflow.

## Release flow

1. Push code to the private repository.
2. CI runs `swift test` plus an unsigned Xcode build.
3. Trigger the `Release` workflow manually with a tag like `v0.1.0`.
4. Approve the `production-release` environment when GitHub prompts for it.
5. The workflow imports the Developer ID certificate, archives the app, submits a ZIP for notarization, staples the `.app`, rebuilds the release ZIP, and generates `appcast.xml`.
6. The workflow uploads ZIP and `appcast.xml` to the GitHub Release.
7. If you want Sparkle auto-update for non-collaborators, publish `dist/updates/appcast.xml` and the release ZIP to external static hosting.

## Internal alpha vs general distribution

### Internal alpha

- Keep everything in the private GitHub repo.
- Invite testers as repository collaborators.
- Let them download ZIP assets from GitHub Releases manually.

### General distribution

- Keep source code private if you want.
- Continue building in GitHub Actions.
- Publish the generated ZIP and `appcast.xml` to public static hosting.
- Keep Sparkle pointed at that public `appcast.xml`.

## Notes

- `swift run CarpdmTerminalApp` is still for local development only.
- Sparkle only activates from a bundled `.app`; the app disables updater setup when launched from `swift run`.
- The release workflow assumes direct distribution outside the Mac App Store.
