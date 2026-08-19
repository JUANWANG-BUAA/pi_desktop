# Upstream RPC request (Direction A)

Pi Desktop chose **Direction A**: keep the product as a visual front-end, and
**stop filling protocol holes with filesystem exemptions**. This file is the
request to `@earendil-works/pi-coding-agent`. Until these commands exist in a
pinned baseline, the desktop will not invent them.

Current baseline: Pi `0.84.2` `docs/rpc.md`. SDK already has
`SessionManager.list` / `listAll`; RPC mode does not expose them.

## Why this is blocking

| Desktop need | Official today | Current exemption |
| --- | --- | --- |
| Session archive | `switch_session` only | Read `~/.pi/agent/sessions/*.jsonl` titles |
| Resource inspector | `get_commands` (slash only) | Recurse `~/.pi/agent` and `.pi/` |
| File attachments | `images` as `ImageContent` | Compose `Attached files: @path` into prompt text |
| Runtime identity | none | Trust PATH `pi`, version pinned only in tests |

Each exemption is a documented deviation in `docs/validation.md`. Direction A
retires them as soon as the commands below ship.

## 1. `get_runtime_info`

Return the process Pi actually is, not the client's guess.

```json
{"id": "req-1", "type": "get_runtime_info"}
```

```json
{
  "id": "req-1",
  "type": "response",
  "command": "get_runtime_info",
  "success": true,
  "data": {
    "package": "@earendil-works/pi-coding-agent",
    "version": "0.84.2",
    "sessionDir": "/Users/me/.pi/agent/sessions",
    "cwd": "/Users/me/src/app",
    "node": "v24.19.0"
  }
}
```

Desktop uses `version` as a **connect-time gate** and `sessionDir` so a custom
`--session-dir` is visible instead of guessed.

## 2. `list_sessions`

Wrap the existing SDK `SessionManager.list` / `listAll`. Do not ask clients to
parse JSONL.

```json
{"id": "req-2", "type": "list_sessions", "cwd": "/Users/me/src/app"}
```

Omit `cwd` (or pass `"all": true`) for `listAll`.

```json
{
  "id": "req-2",
  "type": "response",
  "command": "list_sessions",
  "success": true,
  "data": {
    "sessionDir": "/Users/me/.pi/agent/sessions",
    "sessions": [
      {
        "path": "/Users/me/.pi/agent/sessions/.../x.jsonl",
        "id": "uuid",
        "name": "Optional display name",
        "cwd": "/Users/me/src/app",
        "mtime": "2026-08-19T04:00:00.000Z",
        "preview": "First user-visible text"
      }
    ]
  }
}
```

`switch_session` stays the only mutation path. Listing must survive compact,
long tool output, and path canonicalization — those are why the desktop preview
is wrong today.

## 3. `list_resources`

A read-only inventory of what **this process** loaded: skills, extensions,
prompt templates, themes, MCP servers. `get_commands` is not enough (no themes,
no MCP, no load errors).

```json
{"id": "req-3", "type": "list_resources"}
```

```json
{
  "id": "req-3",
  "type": "response",
  "command": "list_resources",
  "success": true,
  "data": {
    "skills": [{"name": "review", "source": "user", "path": "...", "error": null}],
    "extensions": [],
    "prompts": [],
    "themes": [],
    "mcps": [],
    "diagnostics": ["skipped unreadable settings.json"]
  }
}
```

## 4. File attachments on `prompt` / `steer` / `follow_up`

Images already use `ImageContent`. Files need the same **in-band** rule: the
bytes travel on the RPC record so Pi does not re-read a path that may have
changed.

```json
{
  "type": "prompt",
  "message": "Summarise this spec",
  "files": [
    {
      "type": "file",
      "name": "spec.md",
      "mimeType": "text/markdown",
      "data": "<base64>"
    }
  ]
}
```

Pi should reject oversized payloads with `success: false` rather than silently
truncating. Path-only `@file` expansion stays a TUI convenience and must not be
the RPC contract.

## Desktop commitments once a new baseline ships

1. Bump `docs/pi-baseline.md` and `piBaselineVersion`.
2. Add the new command names to `TODO.md` §3.2 and the boundary-scan allowlist.
3. Drive Archive from `list_sessions`; delete JSONL title scraping.
4. Drive Inspector inventory from `list_resources`; delete `~/.pi` recursion.
5. Send files only as `files[]`; never splice `@path` into `message`.
6. Prefer a bundled runtime; PATH `pi` is accepted only when
   `get_runtime_info.version` matches the pin.

Until then this repository **will not** send `list_sessions`, `list_resources`,
or `files` — inventing them would violate TODO.md §3.2.
