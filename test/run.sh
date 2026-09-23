#!/usr/bin/env bash
# Hermetic tests for install.sh and bin/light-agent: temp HOME, stub claude.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0

ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else fail "$name"; fi; }

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/stub"
cat > "$tmp/stub/claude" <<'STUB'
#!/usr/bin/env bash
{ echo "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
  echo "CLAUDE_CODE_AUTO_COMPACT_WINDOW=$CLAUDE_CODE_AUTO_COMPACT_WINDOW"
  for a in "$@"; do echo "ARG=$a"; done
} > "$HOME/claude.log"
STUB
chmod +x "$tmp/stub/claude"
base_path="/usr/bin:/bin"
export PATH="$tmp/stub:$base_path"

# --- install ---
bash "$repo/install.sh" >/dev/null
check "install creates lme/lml/lma" test -x "$HOME/.local/bin/lme" -a -x "$HOME/.local/bin/lml" -a -x "$HOME/.local/bin/lma"
first="$(cat "$HOME/.local/bin/lme" "$HOME/.local/bin/lml" "$HOME/.local/bin/lma")"
check "install output is idempotent" bash -c 'bash "$1" >/dev/null && [ "$(cat "$2/lme" "$2/lml" "$2/lma")" = "$3" ]' _ "$repo/install.sh" "$HOME/.local/bin" "$first"
check "shortcuts are thin wrappers" grep -q 'bin/light-agent.* explore "\$@"' "$HOME/.local/bin/lme"
check "no symlinks after install" test -z "$(find "$HOME" -type l)"

# --- constitutions ---
con="$HOME/.light-agents"
for m in explore live adhoc; do
  check "install places $m.md" cmp -s "$repo/constitutions/$m.md" "$con/$m.md"
  check "$m.md states its role boundary" bash -c 'grep -q "^## Role boundary" "$1" && grep -q "^\*\*You do:\*\*" "$1" && grep -q "^\*\*You must not:\*\*" "$1"' _ "$con/$m.md"
done
check "constitutions avoid mat lifecycle and proprietary terms" \
  bash -c '! grep -niE "mat (live|explore|duo|adhoc)|supervisor|relay|baton|tmux|auto-refine|shuke" "$@"' _ "$repo"/constitutions/*.md
out="$(bash "$repo/install.sh")"
check "reinstall reports constitutions unchanged" test "$(grep -c '^unchanged ' <<<"$out")" -eq 3
check "reinstall makes no backups" test -z "$(find "$con" -name '*.bak')"
echo "my edit" >> "$con/live.md"
out="$(bash "$repo/install.sh")"
check "modified constitution is backed up" bash -c 'tail -n1 "$1" | grep -qx "my edit"' _ "$con/live.md.bak"
check "modified constitution is refreshed" cmp -s "$repo/constitutions/live.md" "$con/live.md"
check "overwrite prints notice naming backup" grep -qF "saved to $con/live.md.bak" <<<"$out"
rm -f "$con/live.md.bak"

# --- missing constitution ---
rm -f "$con/explore.md"
out="$("$HOME/.local/bin/lme" 2>&1)"; rc=$?
check "missing constitution exits non-zero" test "$rc" -ne 0
check "missing constitution names path" grep -qF "$HOME/.light-agents/explore.md" <<<"$out"
check "missing constitution does not launch claude" test ! -e "$HOME/claude.log"

# --- first run ---
mkdir -p "$HOME/.light-agents"
echo "v1" > "$HOME/.light-agents/explore.md"
"$HOME/.local/bin/lme" --foo "two words"; rc=$?
cfg="$HOME/.mat-agent-home/lme-claude"
check "first run exits 0" test "$rc" -eq 0
check "first run creates config home" test -d "$cfg"
check "first run writes CLAUDE.md" grep -qx v1 "$cfg/CLAUDE.md"
check "CLAUDE_CONFIG_DIR set" grep -qxF "CLAUDE_CONFIG_DIR=$cfg" "$HOME/claude.log"
check "auto-compact window set" grep -qx "CLAUDE_CODE_AUTO_COMPACT_WINDOW=256000" "$HOME/claude.log"
expected_args="ARG=--model=opus[1m]
ARG=--effort
ARG=medium
ARG=--dangerously-skip-permissions
ARG=--foo
ARG=two words"
check "defaults then passthrough args" test "$(grep '^ARG=' "$HOME/claude.log")" = "$expected_args"

# --- refresh on edit ---
echo "v2" > "$HOME/.light-agents/explore.md"
"$HOME/.local/bin/lme" >/dev/null
check "second run refreshes CLAUDE.md" grep -qx v2 "$cfg/CLAUDE.md"
check "no symlinks after launch" test -z "$(find "$HOME" -type l)"

# --- other modes map to their homes ---
echo live > "$HOME/.light-agents/live.md"; echo adhoc > "$HOME/.light-agents/adhoc.md"
"$HOME/.local/bin/lml"; "$HOME/.local/bin/lma"
check "lml uses lml-claude" grep -qx live "$HOME/.mat-agent-home/lml-claude/CLAUDE.md"
check "lma uses lma-claude" grep -qx adhoc "$HOME/.mat-agent-home/lma-claude/CLAUDE.md"

# --- claude missing ---
out="$(PATH="$base_path" "$HOME/.local/bin/lme" 2>&1)"; rc=$?
check "claude missing exits non-zero" test "$rc" -ne 0
check "claude missing message" grep -q "claude not found on PATH" <<<"$out"

# --- bad mode ---
"$repo/bin/light-agent" bogus >/dev/null 2>&1; rc=$?
check "unknown mode exits non-zero" test "$rc" -ne 0

echo
[ "$fails" -eq 0 ] && echo "all tests passed" || { echo "$fails test(s) failed"; exit 1; }
