# Errors

Command failures and integration errors.

---

## [ERR-20260818-001] git-diff-check

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: pending
**Area**: config

### Summary
`git diff --check` could not run because the working directory is not initialized as a Git repository.

### Error
```text
fatal: not a git repository
```

### Context
- Attempted to validate whitespace with `git diff --check` after creating `TODO.md`.
- The directory contains no `.git` metadata.

### Suggested Fix
Initialize or attach the intended Git repository before using Git-based validation. Until then, use direct file and markdown checks.

### Metadata
- Reproducible: yes
- Related Files: TODO.md

---

## [ERR-20260818-002] todo-structural-check

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
A structural assertion counted `## ` substrings inside `###` headings and reported a false failure.

### Error
```text
AssertionError
```

### Context
- The check used `text.count('## ')` instead of counting headings by line prefix.
- The document itself was valid; a line-based check confirmed 16 level-2 headings and 330 unchecked items.

### Suggested Fix
Use `grep '^## '` or a line-prefix parser for Markdown heading checks.

### Metadata
- Reproducible: yes
- Related Files: TODO.md

### Resolution
- **Resolved**: 2026-08-18T10:42:30Z
- **Notes**: Re-ran the structural validation with line-based heading counting.

---

## [ERR-20260818-003] todo-review-count

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
A follow-up TODO validation used an outdated expected count for completed review checkboxes.

### Error
```text
AssertionError
```

### Context
- The document gained a self-review section with 22 completed checks.
- The assertion expected 20 completed checks.

### Suggested Fix
Derive counts from the document or update expected counts after intentional checklist changes.

### Metadata
- Reproducible: yes
- Related Files: TODO.md
- See Also: ERR-20260818-002

### Resolution
- **Resolved**: 2026-08-18T10:42:30Z
- **Notes**: Re-ran the check with the actual count and verified zero trailing whitespace.

---

## [ERR-20260818-004] todo-review-count-after-audit

**Logged**: 2026-08-18T10:42:30Z
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
A validation command used stale expected checkbox counts after adding the second audit section.

### Error
```text
AssertionError
```

### Context
- The second audit intentionally added 5 unchecked and 15 completed review items.
- Actual counts were 336 open TODOs and 37 completed review checks.

### Suggested Fix
Run count discovery before asserting exact values after document edits.

### Metadata
- Reproducible: yes
- Related Files: TODO.md
- See Also: ERR-20260818-003

### Resolution
- **Resolved**: 2026-08-18T10:42:30Z
- **Notes**: Corrected the expected counts and verified zero trailing whitespace.

---
