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

Requires `bash` (Windows Git Bash works) and, depending on the kind, Claude Code (`claude`) or
GitHub Copilot CLI (`copilot`) on `PATH`. `jq` is optional (see [Folder trust](#folder-trust)).

## Commands

| command | mode      | config home                           |
|---------|-----------|---------------------------------------|
| `lme`   | `explore` | `~/.mat-agent-home/lme-<kind>`        |
| `lml`   | `live`    | `~/.mat-agent-home/lml-<kind>`        |
| `lma`   | `adhoc`   | `~/.mat-agent-home/lma-<kind>`        |

## Kinds

The agent CLI is chosen by `--kind <claude|copilot>` as the first argument (`lme --kind copilot`,
or `--kind=copilot`), else by the `LIGHT_AGENT_KIND` environment variable, else `claude`. The flag
wins when both are set. Any other value exits non-zero naming the accepted values. The kind is part
of the config home, so a Claude and a Copilot agent for the same mode never share a home.

| kind      | home variable       | prompt file in home       | config home (e.g. `lme`)        |
|-----------|---------------------|---------------------------|---------------------------------|
| `claude`  | `CLAUDE_CONFIG_DIR` | `CLAUDE.md`               | `~/.mat-agent-home/lme-claude`  |
| `copilot` | `COPILOT_HOME`      | `copilot-instructions.md` | `~/.mat-agent-home/lme-copilot` |

Each launch:

1. Requires the constitution `~/.light-agents/<mode>.md`; if it is missing, exits non-zero
   naming the expected path.
2. Requires the kind's CLI (`claude` or `copilot`) on `PATH`; otherwise exits non-zero.
3. Creates the config home if absent and copies the constitution to the kind's prompt file,
   overwriting it — edits to the source take effect on the next launch.
4. Runs, for `claude`:

   ```sh
   CLAUDE_CONFIG_DIR=<home> CLAUDE_CODE_AUTO_COMPACT_WINDOW=256000 \
     claude --model=opus[1m] --effort medium --dangerously-skip-permissions [your args...]
   ```

   and for `copilot`:

   ```sh
   COPILOT_HOME=<home> COPILOT_SETUP_TERMINAL=false COPILOT_GITHUB_TOKEN=<token> \
     copilot --yolo --model gpt-5.5 --effort medium [your args...]
   ```

   `COPILOT_SETUP_TERMINAL=false` keeps Copilot's blocking terminal-setup prompt from appearing.

Any arguments after the optional `--kind` are appended to the agent invocation verbatim.

### Copilot token

Copilot signs in with a GitHub token taken from the first non-empty of `COPILOT_GITHUB_TOKEN`,
`GH_TOKEN`, `GITHUB_TOKEN` (Copilot's own order), falling back to `gh auth token`. The token must
be a **fine-grained PAT** (`github_pat_…`) or a **`gh` OAuth token** (`gho_…`): Copilot rejects
classic PATs, so a token starting with `ghp_` exits non-zero before launching. With no token at
all the launch exits non-zero naming `COPILOT_GITHUB_TOKEN`.

### Folder trust

Copilot asks whether to trust the working directory before it starts, and no launch flag
(`--yolo` included) skips that prompt. Before launching, the launcher adds the current directory
to `trustedFolders` in `<home>/config.json`, keeping the file's other keys and header comments.
This needs `jq`. Without `jq` the launcher prints a warning and launches anyway, and Copilot asks
once per folder; answer it and Copilot remembers the choice in the same home.

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
