# Local Watch Install Design

## Goal

Make local development closer to an installed app workflow by rebuilding and reinstalling the macOS app automatically when source files change.

## Recommendation

Use a lightweight polling watcher script that wraps the existing local install script.

Reasons:

- No extra dependency like `fswatch`, `entr`, or `watchexec`
- Works immediately on a clean macOS setup
- Reuses the existing `install_local_app.sh` path instead of creating a second build flow

## Workflow

1. Watch a small set of project inputs: `Sources`, `Config`, `project.yml`, `Package.swift`, `Package.resolved`.
2. Compute a snapshot hash from file modification time and path.
3. On change, call `scripts/dev/install_local_app.sh`.
4. After a successful install, restart the app so code changes are reflected in the running instance.

## Trade-offs

### Recommended: polling watcher

- Zero external tooling
- Simple to debug
- Good enough for local app iteration

### Alternative: `fswatch`

- More immediate file events
- Adds a developer dependency that may not be installed

### Alternative: Xcode-only loop

- Best for active implementation
- Does not help when testing the app like a normally installed bundle
