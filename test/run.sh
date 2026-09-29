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

# --- copilot kind ---
cat > "$tmp/stub/copilot" <<'STUB'
#!/usr/bin/env bash
{ echo "COPILOT_HOME=$COPILOT_HOME"
  echo "COPILOT_SETUP_TERMINAL=$COPILOT_SETUP_TERMINAL"
  echo "COPILOT_GITHUB_TOKEN=$COPILOT_GITHUB_TOKEN"
  for a in "$@"; do echo "ARG=$a"; done
} > "$HOME/copilot.log"
STUB
chmod +x "$tmp/stub/copilot"
unset COPILOT_GITHUB_TOKEN GH_TOKEN GITHUB_TOKEN LIGHT_AGENT_KIND
export COPILOT_GITHUB_TOKEN=github_pat_fine
cop="$HOME/.mat-agent-home/lme-copilot"
work="$tmp/work"; mkdir -p "$work"
trust_dir="$work"; command -v cygpath >/dev/null 2>&1 && trust_dir="$(cygpath -w "$work")"
config_body() { grep -v '^[[:space:]]*//' "$cop/config.json"; }

rm -f "$HOME/claude.log"
(cd "$work" && "$HOME/.local/bin/lme" --kind copilot --foo "two words"); rc=$?
check "--kind copilot exits 0" test "$rc" -eq 0
check "--kind copilot does not launch claude" test ! -e "$HOME/claude.log"
check "copilot home is lme-copilot" grep -qxF "COPILOT_HOME=$cop" "$HOME/copilot.log"
check "constitution installed as copilot-instructions.md" grep -qx v2 "$cop/copilot-instructions.md"
check "copilot home has no CLAUDE.md" test ! -e "$cop/CLAUDE.md"
check "COPILOT_SETUP_TERMINAL=false exported" grep -qx "COPILOT_SETUP_TERMINAL=false" "$HOME/copilot.log"
check "token exported" grep -qx "COPILOT_GITHUB_TOKEN=github_pat_fine" "$HOME/copilot.log"
expected_args="ARG=--yolo
ARG=--model
ARG=gpt-5.5
ARG=--effort
ARG=medium
ARG=--foo
ARG=two words"
check "copilot defaults then passthrough args" test "$(grep '^ARG=' "$HOME/copilot.log")" = "$expected_args"
check "cwd seeded into trustedFolders" bash -c 'grep -v "^[[:space:]]*//" "$1" | jq -e --arg d "$2" ".trustedFolders == [\$d]" >/dev/null' _ "$cop/config.json" "$trust_dir"
(cd "$work" && "$HOME/.local/bin/lme" --kind=copilot); rc=$?
check "--kind=copilot form works" test "$rc" -eq 0
check "trust seeding is idempotent" test "$(config_body | jq '.trustedFolders | length')" -eq 1

# existing Copilot-managed config: header comments and other keys survive
printf '// This file is managed automatically.\n{\n  "loggedInUsers": [1],\n  "trustedFolders": ["X:\\\\other"]\n}\n' > "$cop/config.json"
(cd "$work" && "$HOME/.local/bin/lme" --kind copilot)
check "config header comment kept" grep -qx '// This file is managed automatically.' "$cop/config.json"
check "config keys kept and cwd appended" bash -c 'grep -v "^[[:space:]]*//" "$1" | jq -e --arg d "$2" ".loggedInUsers == [1] and .trustedFolders == [\"X:\\\\other\", \$d]" >/dev/null' _ "$cop/config.json" "$trust_dir"

rm -f "$HOME/copilot.log"
LIGHT_AGENT_KIND=copilot "$HOME/.local/bin/lml"; rc=$?
check "LIGHT_AGENT_KIND=copilot launches copilot" grep -qxF "COPILOT_HOME=$HOME/.mat-agent-home/lml-copilot" "$HOME/copilot.log"
rm -f "$HOME/claude.log"
LIGHT_AGENT_KIND=copilot "$HOME/.local/bin/lml" --kind claude
check "--kind wins over LIGHT_AGENT_KIND" grep -qxF "CLAUDE_CONFIG_DIR=$HOME/.mat-agent-home/lml-claude" "$HOME/claude.log"
rm -f "$HOME/claude.log"
"$HOME/.local/bin/lme"
check "bare lme still launches claude" grep -qxF "CLAUDE_CONFIG_DIR=$cfg" "$HOME/claude.log"

out="$("$HOME/.local/bin/lme" --kind gemini 2>&1)"; rc=$?
check "unknown kind exits non-zero" test "$rc" -ne 0
check "unknown kind names accepted values" grep -qF "accepted values: claude, copilot" <<<"$out"
out="$(LIGHT_AGENT_KIND=bogus "$HOME/.local/bin/lme" 2>&1)"; rc=$?
check "unknown LIGHT_AGENT_KIND exits non-zero" test "$rc" -ne 0

# token resolution
rm -f "$HOME/copilot.log"
out="$(COPILOT_GITHUB_TOKEN=ghp_classic "$HOME/.local/bin/lme" --kind copilot 2>&1)"; rc=$?
check "classic PAT exits non-zero" test "$rc" -ne 0
check "classic PAT names the reason" grep -qF "classic PAT" <<<"$out"
check "classic PAT does not launch copilot" test ! -e "$HOME/copilot.log"
out="$(COPILOT_GITHUB_TOKEN= GH_TOKEN=ghp_classic "$HOME/.local/bin/lme" --kind copilot 2>&1)"; rc=$?
check "classic PAT in GH_TOKEN is refused" bash -c '[ "$1" -ne 0 ] && grep -qF "GH_TOKEN holds a classic PAT" <<<"$2"' _ "$rc" "$out"
out="$(COPILOT_GITHUB_TOKEN= "$HOME/.local/bin/lme" --kind copilot 2>&1)"; rc=$?
check "missing token exits non-zero" test "$rc" -ne 0
check "missing token names the variable" grep -qF "COPILOT_GITHUB_TOKEN" <<<"$out"
check "missing token does not launch copilot" test ! -e "$HOME/copilot.log"
printf '#!/usr/bin/env bash\n[ "$*" = "auth token" ] && echo gho_oauth\n' > "$tmp/stub/gh"; chmod +x "$tmp/stub/gh"
COPILOT_GITHUB_TOKEN= "$HOME/.local/bin/lme" --kind copilot
check "gh auth token fallback" grep -qx "COPILOT_GITHUB_TOKEN=gho_oauth" "$HOME/copilot.log"
rm -f "$tmp/stub/gh"

# --- model/effort resolution ---
unset COPILOT_GITHUB_TOKEN; export COPILOT_GITHUB_TOKEN=github_pat_fine
args() { grep '^ARG=' "$HOME/$1.log" | head -n "$2" | tr '\n' ' '; }
launch() { rm -f "$HOME/claude.log" "$HOME/copilot.log"; out="$(cd "$work" && "$HOME/.local/bin/lme" "$@" 2>&1)"; rc=$?; }

launch
check "no table: built-in defaults" test "$(args claude 3)" = "ARG=--model=opus[1m] ARG=--effort ARG=medium "
launch --backend sonnet
check "nickname without any table warns" bash -c '[ "$1" -eq 0 ] && grep -qF "no readable backends.json" <<<"$2"' _ "$rc" "$out"
check "nickname without any table uses defaults" test "$(args claude 3)" = "ARG=--model=opus[1m] ARG=--effort ARG=medium "

matcfg="$HOME/.config/mat"; mkdir -p "$matcfg"
cat > "$matcfg/backends.json" <<'JSON'
{"backends": [
  {"nickname": "sonnet", "kind": "claude", "default_model": "sonnet[1m]", "default_effort": "high", "config_dir": "claudew", "prompt_file": "X.md"},
  {"nickname": "bare", "kind": "claude", "default_model": "", "default_effort": null},
  {"nickname": "cop", "kind": "copilot", "default_model": "gpt-5.6-luna", "default_effort": "max"},
  {"nickname": "grok", "kind": "grok", "default_model": "grok-4.6", "default_effort": "high"}
]}
JSON
mat_before="$(ls -laR --time-style=full-iso "$matcfg"; cksum "$matcfg/backends.json")"

launch
check "table present, no nickname: defaults" test "$(args claude 3)" = "ARG=--model=opus[1m] ARG=--effort ARG=medium "
launch --backend sonnet --foo
check "nickname resolves mat entry" test "$(args claude 5)" = "ARG=--model=sonnet[1m] ARG=--effort ARG=high ARG=--dangerously-skip-permissions ARG=--foo "
check "mat config_dir is not inherited" grep -qxF "CLAUDE_CONFIG_DIR=$cfg" "$HOME/claude.log"
LIGHT_AGENT_BACKEND=sonnet launch
check "LIGHT_AGENT_BACKEND selects the entry" test "$(args claude 3)" = "ARG=--model=sonnet[1m] ARG=--effort ARG=high "
launch --backend=sonnet --model opus --effort=low
check "flags override the table" test "$(args claude 3)" = "ARG=--model=opus ARG=--effort ARG=low "
LIGHT_AGENT_MODEL=m1 LIGHT_AGENT_EFFORT=e1 launch --backend sonnet
check "env overrides the table" test "$(args claude 3)" = "ARG=--model=m1 ARG=--effort ARG=e1 "
LIGHT_AGENT_MODEL=m1 launch --model m2
check "flag overrides env" test "$(args claude 1)" = "ARG=--model=m2 "
launch --model opus
check "flag overrides defaults without table lookup" test "$(args claude 3)" = "ARG=--model=opus ARG=--effort ARG=medium "
launch --backend bare
check "empty entry fields fall back per field" test "$(args claude 3)" = "ARG=--model=opus[1m] ARG=--effort ARG=medium "
launch --backend cop
check "entry kind selects copilot" test "$(args copilot 5)" = "ARG=--yolo ARG=--model ARG=gpt-5.6-luna ARG=--effort ARG=max "
launch --kind claude --backend cop
check "explicit kind conflicting with entry exits non-zero" bash -c '[ "$1" -ne 0 ] && grep -qF "backend '\''cop'\'' has kind '\''copilot'\''" <<<"$2"' _ "$rc" "$out"
launch --backend grok
check "unsupported entry kind exits non-zero" bash -c '[ "$1" -ne 0 ] && grep -qF "accepted values: claude, copilot" <<<"$2"' _ "$rc" "$out"
launch --backend nosuch
check "unknown nickname exits non-zero naming it" bash -c '[ "$1" -ne 0 ] && grep -qF "unknown backend '\''nosuch'\''" <<<"$2"' _ "$rc" "$out"
check "unknown nickname does not launch" test ! -e "$HOME/claude.log"

# light-agents' own table wins over mat's
printf '{"backends":[{"nickname":"sonnet","kind":"claude","default_model":"own","default_effort":"low"}]}\n' > "$HOME/.light-agents/backends.json"
launch --backend sonnet
check "light-agents table wins over mat" test "$(args claude 3)" = "ARG=--model=own ARG=--effort ARG=low "
launch --backend cop
check "nickname falls through to mat table" grep -qx "ARG=gpt-5.6-luna" "$HOME/copilot.log"
echo 'not json' > "$HOME/.light-agents/backends.json"
launch --backend sonnet
check "malformed own table is skipped with warning" bash -c '[ "$1" -eq 0 ] && grep -qF "malformed $2" <<<"$3"' _ "$rc" "$HOME/.light-agents/backends.json" "$out"
check "malformed own table falls to mat" grep -qx "ARG=--model=sonnet\[1m\]" "$HOME/claude.log"
rm -f "$HOME/.light-agents/backends.json"

cp -p "$matcfg/backends.json" "$tmp/mat-backends.json"
printf '{"backends": [' > "$matcfg/backends.json"
launch --backend sonnet
check "malformed mat table does not abort" test "$rc" -eq 0
check "malformed mat table warns" grep -qF "malformed $matcfg/backends.json" <<<"$out"
check "malformed mat table uses defaults" test "$(args claude 3)" = "ARG=--model=opus[1m] ARG=--effort ARG=medium "
cp -p "$tmp/mat-backends.json" "$matcfg/backends.json"

# jq absent: PATH holds only the stubs and wrappers for the tools the launcher needs
nojq="$tmp/nojq"; mkdir -p "$nojq"
for t in bash cp mkdir; do printf '#!/bin/sh\nexec /usr/bin/%s "$@"\n' "$t" > "$nojq/$t"; chmod +x "$nojq/$t"; done
rm -f "$HOME/claude.log"
out="$(PATH="$tmp/stub:$nojq" "$HOME/.local/bin/lme" --backend sonnet 2>&1)"; rc=$?
check "no jq: launch still succeeds" test "$rc" -eq 0
check "no jq: warning names jq" grep -qF "jq not found" <<<"$out"
check "no jq: built-in defaults" test "$(args claude 3)" = "ARG=--model=opus[1m] ARG=--effort ARG=medium "

check "no write under ~/.config/mat" test "$(ls -laR --time-style=full-iso "$matcfg"; cksum "$matcfg/backends.json")" = "$mat_before"

# copilot missing
rm -f "$tmp/stub/copilot"
out="$("$HOME/.local/bin/lme" --kind copilot 2>&1)"; rc=$?
check "copilot missing exits non-zero" test "$rc" -ne 0
check "copilot missing message" grep -q "copilot not found on PATH" <<<"$out"

echo
[ "$fails" -eq 0 ] && echo "all tests passed" || { echo "$fails test(s) failed"; exit 1; }
