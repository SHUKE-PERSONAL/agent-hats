#!/usr/bin/env bash
# Install the lme/lml/lma shortcuts into ~/.local/bin.
# Each shortcut is a generated wrapper over bin/light-agent; re-running
# overwrites them in place.
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
