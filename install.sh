#!/usr/bin/env bash
# Install the lme/lml/lma shortcuts into ~/.local/bin and the constitutions
# into ~/.light-agents. Each shortcut is a generated wrapper over
# bin/light-agent; re-running overwrites them in place. A constitution that
# differs from the repo copy is backed up to <mode>.md.bak before overwrite.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bindir="$HOME/.local/bin"
mkdir -p "$bindir"

for pair in lme:explore lml:live lma:adhoc; do
  name="${pair%%:*}" mode="${pair#*:}"
  target="$bindir/$name"
  rm -f "$target"
  printf '#!/usr/bin/env bash\nexec %q %s "$@"\n' "$repo/bin/light-agent" "$mode" > "$target"
  chmod +x "$target"
  echo "installed $target -> $mode"
done

condir="$HOME/.light-agents"
mkdir -p "$condir"
for mode in explore live adhoc; do
  src="$repo/constitutions/$mode.md"
  dst="$condir/$mode.md"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    echo "installed $dst"
  elif cmp -s "$src" "$dst"; then
    echo "unchanged $dst"
  else
    cp -f "$dst" "$dst.bak"
    cp -f "$src" "$dst"
    echo "notice: $dst differed from the repo copy; previous version saved to $dst.bak"
  fi
done
