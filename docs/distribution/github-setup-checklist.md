# GitHub Public Repo Setup Checklist

CarpdmTerminal public repository bootstrap checklist for `https://github.com/skdkfk8758/carpdm-terminal`.

## 1. Repository baseline

- [x] Repository visibility is `Public`
- [x] Default branch is `main`
- [x] Local repository remote `origin` points to `https://github.com/skdkfk8758/carpdm-terminal.git`
- [x] Initial source tree is pushed from local `main`

## 2. Release environment

GitHub path: `Settings -> Environments -> New environment`

- [ ] Create environment `production-release`
- [ ] Add required reviewers for release approval
- [ ] Restrict deployment branches to `main`
- [ ] Add environment secrets:
  - [ ] `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64`
  - [ ] `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`
  - [ ] `APPLE_TEAM_ID`
  - [ ] `APPLE_ID`
  - [ ] `APPLE_APP_SPECIFIC_PASSWORD`
  - [ ] `APPLE_NOTARY_TEAM_ID`
  - [ ] `KEYCHAIN_PASSWORD`
  - [ ] `SPARKLE_FEED_URL`
  - [ ] `SPARKLE_PUBLIC_ED_KEY`
  - [ ] `SPARKLE_PRIVATE_KEY`
  - [ ] `SPARKLE_DOWNLOAD_BASE_URL`

## 3. Branch and tag protection

GitHub path: `Settings -> Branches`

- [ ] Protect `main`
- [ ] Require pull request before merge
- [ ] Require status checks for CI before merge
- [ ] Restrict direct push to trusted maintainers

GitHub path: `Settings -> Rules -> Rulesets`

- [ ] Add tag protection or ruleset for `v*`
- [ ] Restrict release tag creation to trusted maintainers

## 4. Security settings

GitHub path: `Settings -> Security`

- [ ] Enable Dependabot alerts
- [ ] Enable Dependabot security updates
- [ ] Enable secret scanning
- [ ] Enable push protection for secrets
- [ ] Enable private vulnerability reporting
- [ ] Confirm [`SECURITY.md`](/Users/carpdm/Workspace/CarpdmTerminal/SECURITY.md) is visible in repo root

## 5. Actions and release workflow

GitHub path: `Settings -> Actions -> General`

- [ ] Allow GitHub Actions for this repository
- [ ] Keep workflow permissions at least `Read repository contents`
- [ ] Do not add Apple/Sparkle secrets at repository level

GitHub path: `Actions -> Release`

- [ ] Confirm release workflow requires manual `workflow_dispatch`
- [ ] Confirm `production-release` approval is requested before signing starts
- [ ] Confirm release tag format is `vX.Y.Z`

## 6. Update distribution

- [ ] Decide public Sparkle hosting target
  - [ ] GitHub Pages
  - [ ] Cloudflare R2 or S3
  - [ ] Other static HTTPS hosting
- [ ] Publish notarized DMG, ZIP, and `appcast.xml`
- [ ] Keep `SPARKLE_FEED_URL` pointed at the public `appcast.xml`
- [ ] Verify downloaded archive URL matches `SPARKLE_DOWNLOAD_BASE_URL`

## 7. First release dry run

- [ ] Merge current code into `main`
- [ ] Trigger `Release` workflow with a test tag such as `v0.1.0`
- [ ] Approve `production-release`
- [ ] Confirm DMG, ZIP, and `appcast.xml` artifacts are produced
- [ ] Confirm GitHub Release is created
- [ ] Sync artifacts to update host
- [ ] Install the `.app` bundle and verify Sparkle can check for updates
