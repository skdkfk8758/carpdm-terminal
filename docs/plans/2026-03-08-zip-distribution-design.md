# ZIP Distribution Design

## Goal

Make GitHub Release and Sparkle distribution ZIP-first so the MVP ships one primary install artifact instead of maintaining both ZIP and DMG in the release path.

## Recommendation

Use a notarized ZIP as the canonical release artifact.

Reasons:

- The app already builds a standalone `.app` bundle that fits direct ZIP distribution.
- Sparkle supports ZIP archives as update payloads.
- ZIP is simpler than DMG for internal and external distribution because there is no extra disk image authoring step.
- The release pipeline becomes smaller: build app, notarize, staple app, rebuild ZIP, publish ZIP and `appcast.xml`.

## Workflow

1. Build a signed `.app` archive in CI.
2. Create a temporary ZIP from the `.app`.
3. Submit that ZIP to Apple notarization.
4. After notarization succeeds, staple the `.app`.
5. Rebuild the final release ZIP from the stapled `.app`.
6. Generate Sparkle `appcast.xml` from the ZIP.
7. Upload ZIP and `appcast.xml` to GitHub Release and the public update host.

## Trade-offs

### Recommended: ZIP only

- Smallest operational surface
- Best fit for Sparkle
- Easiest release automation

### Alternative: ZIP + DMG

- Better “drag to Applications” presentation
- More operational complexity
- Two public artifacts to validate every release

### Alternative: PKG

- Useful only if the app later installs helpers, launch agents, or CLI shims
- Too heavy for the current MVP
