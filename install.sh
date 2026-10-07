#!/usr/bin/env bash
# Install the hat command into ~/.local/bin, and the constitutions and the
# default backends table into ~/.agent-hats. The command is a generated
# wrapper over bin/hat; re-running overwrites it in place. A constitution or
# the table is copied only when missing; an existing one is the user's and is
# never overwritten.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bindir="$HOME/.local/bin"
mkdir -p "$bindir"

target="$bindir/hat"
rm -f "$target"
printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$repo/bin/hat" > "$target"
chmod +x "$target"
echo "installed $target"

condir="$HOME/.agent-hats"
mkdir -p "$condir"
for src in "$repo"/constitutions/{explore,live,adhoc,audit}.md "$repo/backends.json"; do
  dst="$condir/${src##*/}"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    echo "installed $dst"
  elif cmp -s "$src" "$dst"; then
    echo "unchanged $dst"
  else
    echo "kept $dst (differs from $src)"
  fi
done
