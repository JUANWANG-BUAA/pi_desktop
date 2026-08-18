#!/usr/bin/env bash
# Installs tool/check.sh as the local pre-commit hook so the commit gate
# from docs/implementation-plan.md "提交规则" cannot be skipped by accident.
# Git hooks are local (not pushed), so run this once per clone.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

hook=".git/hooks/pre-commit"
cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
exec "$(git rev-parse --show-toplevel)/tool/check.sh"
HOOK
chmod +x "$hook"

echo "pre-commit hook installed at $hook"
