# Security policy

[简体中文](SECURITY.md) · English

## Current stage

Chengyin Companion remains a local prototype and does not yet have a supported public release. GitHub Private Vulnerability Reporting will be enabled after the canonical public repository is created.

## What to report privately

Report these problems privately rather than opening a public Issue first:

- content-pack path traversal, signature bypass, or arbitrary code execution;
- license or entitlement forgery, or purchase-data disclosure;
- updater hijacking or rollback-protection failure;
- Codex event bridging that reads data outside its documented boundary;
- disclosure of user settings, backups, or diagnostics;
- abnormal application signing or notarization behaviour.

Ordinary crashes, interface bugs, and content-pack compatibility problems with no security impact may use a public Issue.

## Secrets and credentials

- The repository and App Bundle never store Volcengine, payment, signing, or Apple Developer private keys.
- Local development uses environment variables or the system Keychain.
- Logs must remove tokens, purchase records, and identifiable local paths.
- Revoke any credential immediately after accidental submission; deleting Git history alone does not restore security.

Run `python3 scripts/audit-public-source-secrets.py --json` before contribution
or packaging. It performs an offline, bounded scan of the public-source
allowlist for private keys, known provider tokens, embedded basic authentication,
suspicious credential assignments, and high-risk credential files. Receipts
contain no matched content and it reads neither environment values nor private
user directories. This is an accidental-leak guard—not malicious-code analysis
or proof that Git history never held a secret.

## Content safety

A public release accepts only adult fictional-character media with explicit usage rights. When rights to a real person’s likeness, voice, music, or video are disputed, immediately pause distribution of the affected pack while preserving a safe withdrawal and refund path.
