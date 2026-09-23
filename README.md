# light-agents
Lightweight, constitution-driven agent launcher — borrows mat's standalone toolset, runs happily on Windows

## Install

```sh
./install.sh
```

This writes three shortcuts into `~/.local/bin` (which must be on `PATH`). Each is a two-line
wrapper that execs `bin/light-agent` from this checkout by absolute path — a generated file,
not a symlink. Re-running `install.sh` is safe and overwrites them in place; re-run it after
moving the checkout.

Requires `bash` (Windows Git Bash works) and Claude Code (`claude`) on `PATH`.

## Commands

| command | mode      | config home                     |
|---------|-----------|---------------------------------|
| `lme`   | `explore` | `~/.mat-agent-home/lme-claude`  |
| `lml`   | `live`    | `~/.mat-agent-home/lml-claude`  |
| `lma`   | `adhoc`   | `~/.mat-agent-home/lma-claude`  |

Each launch:

1. Requires the constitution `~/.light-agents/<mode>.md`; if it is missing, exits non-zero
   naming the expected path.
2. Requires `claude` on `PATH`; otherwise exits non-zero.
3. Creates the config home if absent and copies the constitution to `<home>/CLAUDE.md`,
   overwriting it — edits to the source take effect on the next launch.
4. Runs:

   ```sh
   CLAUDE_CONFIG_DIR=<home> CLAUDE_CODE_AUTO_COMPACT_WINDOW=256000 \
     claude --model=opus[1m] --effort medium --dangerously-skip-permissions [your args...]
   ```

Any arguments given to `lme`/`lml`/`lma` are appended to the `claude` invocation verbatim.

## Constitution contract

`~/.light-agents/<mode>.md` (`explore.md`, `live.md`, `adhoc.md`) is one self-contained
Markdown file per mode. It becomes that mode's user-level `CLAUDE.md`. There is no
composition or shared-snippet layer.

## Tests

```sh
bash test/run.sh
```
