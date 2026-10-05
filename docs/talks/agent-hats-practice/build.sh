#!/usr/bin/env bash
# Build agent-hats-practice.pptx (with speaker notes) and agent-hats-practice.pdf from the Marp source.
set -euo pipefail

cd "$(dirname "$0")"
export CHROME_PATH="${CHROME_PATH:-/usr/bin/google-chrome}"

# Prefer a cached marp-cli (offline, fast); fall back to fetching it via npx.
MARP=$(ls -d ~/.npm/_npx/*/node_modules/.bin/marp 2>/dev/null | head -1 || true)
if [[ -z "$MARP" ]]; then
  MARP="npx -y @marp-team/marp-cli"
fi

# --no-stdin: marp otherwise waits on stdin when it is not a TTY. Time out and retry once anyway.
render() {
  local fmt=$1
  for attempt in 1 2; do
    if timeout 180 $MARP agent-hats-practice.md "--$fmt" --html --allow-local-files --no-stdin -o "agent-hats-practice.$fmt"; then
      return 0
    fi
    echo "render $fmt failed (attempt $attempt)" >&2
  done
  return 1
}

render pptx
render pdf
ls -l agent-hats-practice.pptx agent-hats-practice.pdf
