# Security Policy

## Supported versions

Only the latest commit on `main` and tagged releases (when they exist) receive
security fixes. Development snapshots are not supported.

Pi Desktop is a thin client for `@earendil-works/pi-coding-agent`. Vulnerabilities
in Pi itself should be reported to the [Pi project](https://github.com/earendil-works/pi),
not here.

## Reporting a vulnerability

Please use GitHub's **Privately report a vulnerability** flow on this
repository. Do not file a public issue, pull request, or discussion for a
suspected vulnerability.

Include:

- Pi Desktop commit or version
- Pi version (`pi --version`) and Flutter version
- What an attacker can do, and a minimal reproduction if you have one

You should receive an acknowledgement within 7 days. We will tell you whether
the report is accepted, declined as out of scope, or forwarded upstream to Pi.

## Out of scope

- Issues that require the user to already run untrusted Pi extensions or skills
- Missing macOS notarization / code signing on unsigned development builds
- Secrets, API keys, or Session JSONL committed by a contributor — rotate the
  secret first, then tell us so we can purge it from git history if needed

## Product constraints

Pi Desktop must not store a second copy of sessions, call model providers
directly, or invent a plugin protocol. See `TODO.md` §15. A security fix that
would violate that contract is not acceptable; the fix must stay on the Pi RPC
boundary.
