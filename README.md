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

It also installs the three constitutions from `constitutions/` into `~/.light-agents/`:

- missing: copied in (`installed <path>`);
- identical to the repo copy: left alone (`unchanged <path>`);
- different (you edited it, or the repo copy changed): the existing file is saved to
  `<mode>.md.bak`, the repo copy is installed, and a `notice:` line names the backup.

To keep a local edit, merge it back from the `.bak` after re-installing, or edit
`constitutions/<mode>.md` in your checkout instead.

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
composition or shared-snippet layer; the three files repeat each other on purpose.

| mode      | role                                                                 |
|-----------|----------------------------------------------------------------------|
| `explore` | investigates and writes tickets; does not write delivery code        |
| `live`    | hands-on generalist: implements, tests, commits in the working repo  |
| `adhoc`   | executes one operator-given task end to end, then stops              |

Each file has a `## Role boundary` section stating what the mode does and must not do.

## Tests

```sh
bash test/run.sh
```
