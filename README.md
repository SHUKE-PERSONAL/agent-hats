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
GitHub Copilot CLI (`copilot`) on `PATH`. `jq` is optional (see [Claude first run](#claude-first-run),
[Folder trust](#folder-trust) and [Model and effort](#model-and-effort)).

## Commands

| command | mode      | config home                           |
|---------|-----------|---------------------------------------|
| `lme`   | `explore` | `~/.mat-agent-home/lme-<kind>`        |
| `lml`   | `live`    | `~/.mat-agent-home/lml-<kind>`        |
| `lma`   | `adhoc`   | `~/.mat-agent-home/lma-<kind>`        |

## Kinds

The agent CLI is chosen by `--kind <claude|copilot>` (`lme --kind copilot`, or `--kind=copilot`),
else by the `LIGHT_AGENT_KIND` environment variable, else by the kind of the selected
[backend](#model-and-effort), else `claude`. The flag wins when both are set. Any other value exits
non-zero naming the accepted values. The kind is part of the config home, so a Claude and a Copilot agent for the same mode never share a home.

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
4. For `claude`, pre-answers the first-run prompts (see [Claude first run](#claude-first-run)).
5. Runs, for `claude`:

   ```sh
   CLAUDE_CONFIG_DIR=<home> CLAUDE_CODE_AUTO_COMPACT_WINDOW=256000 ANTHROPIC_AUTH_TOKEN=<token> \
     claude --model=<model> --effort <effort> --dangerously-skip-permissions [your args...]
   ```

   and for `copilot`:

   ```sh
   COPILOT_HOME=<home> COPILOT_SETUP_TERMINAL=false COPILOT_GITHUB_TOKEN=<token> \
     copilot --yolo --model <model> --effort <effort> [your args...]
   ```

   `COPILOT_SETUP_TERMINAL=false` keeps Copilot's blocking terminal-setup prompt from appearing.

Launcher options (`--kind`, `--backend`, `--model`, `--effort`, each also as `--opt=value`) are
read only before the first other argument; that argument and everything after it are appended to
the agent invocation verbatim.

### Model and effort

`<model>` and `<effort>` are each resolved separately, first match wins:

1. `--model` / `--effort`, else `LIGHT_AGENT_MODEL` / `LIGHT_AGENT_EFFORT`.
2. The backend entry selected by `--backend <nickname>` (else `LIGHT_AGENT_BACKEND`), looked up in
   `~/.light-agents/backends.json`, then in mat's `~/.config/mat/backends.json`.
3. Built-in defaults: `opus[1m]` / `medium` for `claude`, `gpt-5.5` / `medium` for `copilot`.

Both tables are optional and share mat's schema:

```json
{"backends": [
  {"nickname": "sonnet", "kind": "claude", "default_model": "sonnet[1m]", "default_effort": "high"}
]}
```

Only `nickname`, `kind`, `default_model`, `default_effort` and (for `claude`, see
[Claude token](#claude-token)) `auth_var` are read; other fields (`config_dir`, `prompt_file`, …)
are ignored, and an empty or missing model or effort falls to the
built-in default. The entry's `kind` selects the kind unless one is given explicitly; an explicit
kind that differs, or an entry kind other than `claude`/`copilot`, exits non-zero.

Without `--backend` no table is read. The tables are only ever read, never written, and a lookup
is best-effort: without `jq`, or when no table exists, the launcher warns and uses the built-in
defaults; an unreadable or malformed table is skipped with a warning. A nickname that no readable
table contains exits non-zero naming it.

### Claude token

Claude signs in with a long-lived token from `claude setup-token`, read from the selected backend's
`auth_var` (the name of an environment variable), else from `CLAUDE_CODE_OAUTH_TOKEN`:

```sh
claude setup-token                      # once; prints sk-ant-oat01-...
export CLAUDE_CODE_OAUTH_TOKEN=<token>  # e.g. in ~/.bashrc
```

The launcher passes it as `ANTHROPIC_AUTH_TOKEN` and drops `CLAUDE_CODE_OAUTH_TOKEN`, because Claude
prefers a stale `.credentials.json` in the home over `CLAUDE_CODE_OAUTH_TOKEN`. One token serves
every mode's home. If the variable is empty and neither `ANTHROPIC_AUTH_TOKEN` nor
`ANTHROPIC_API_KEY` is set, the launcher warns and launches anyway, and Claude asks you to `/login`
once per home.

### Claude first run

A fresh Claude home would stop on onboarding, the folder-trust dialog and the bypass-permissions
warning. Before launching, the launcher sets `hasCompletedOnboarding` and trusts the project in
`<home>/.claude.json`, and sets `skipDangerousModePermissionPrompt` in `<home>/settings.json`. Other
keys are kept, and a file is rewritten only when a value changes. The trusted key is the git common
root (the main checkout, also when launched from a worktree), else the current directory. Without
`jq`, a missing file is created with just the onboarding or bypass setting, an existing one is left
alone, and Claude asks once per folder whether to trust it. A file that is not valid JSON stops the
launch.

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

## License

[MIT](LICENSE)
