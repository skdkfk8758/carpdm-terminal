# Security Policy

## Supported Releases

Only the latest tagged release is supported for security fixes.

## Reporting a Vulnerability

Do not open public GitHub issues for security-sensitive reports.

Use GitHub private vulnerability reporting if it is enabled for this repository. If private vulnerability reporting is unavailable, contact the maintainers directly and include:

- A concise description of the issue
- Reproduction steps
- Affected version or tag
- Any proof-of-concept or logs needed to verify impact

Please avoid posting signing material, tokens, or private user data in the report.

## Release Security Expectations

- Signed releases are published only through the `production-release` GitHub environment.
- Apple signing credentials and Sparkle signing keys must live in environment secrets, not repository secrets.
- Workflow changes that touch signing, notarization, release upload, or Sparkle feed generation should be reviewed as security-sensitive changes.
