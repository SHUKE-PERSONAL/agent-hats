<p align="center"><img src="assets/logo.svg" alt="agent-hats logo: a pith helmet, a hard hat and a cap" width="360"></p>

# agent-hats

Same harness, different hat. `hat explore`, `hat live` and `hat adhoc` start Claude Code or
GitHub Copilot CLI wearing a hat — and a hat is more than a name: each one carries a
[constitution](#constitution-contract), a rules file that says what the role does and must not do.
That is why one agent, under different hats, does different jobs well. Each hat also gets its own
config home, so the roles never bleed into each other. Plain `bash`; runs on Linux, macOS and
Windows Git Bash.

Three hats ship with the repo; any Markdown file you drop into `~/.agent-hats/` is another
(see [Your own hats](#your-own-hats)).

| hat          | role                                                                 |
|--------------|----------------------------------------------------------------------|
| `explore`    | investigates and writes tickets; does not write delivery code        |
| `live`       | hands-on generalist: implements, tests, commits in the working repo  |
| `adhoc`      | executes one operator-given task end to end, then stops              |

```sh
hat live                # Claude Code in live mode
hat live sonnet         # same, with the "sonnet" backend (model, effort, token)
hat explore --kind copilot
hat adhoc -- "bump the version"   # with an initial prompt
```

## Install

```sh
./install.sh
```

This writes the `hat` command into `~/.local/bin` (which must be on `PATH`). It is a two-line
wrapper that execs `bin/hat` from this checkout by absolute path — a generated file, not a
symlink. Re-running `install.sh` is safe and overwrites it in place; re-run it after moving the
checkout.

It also installs the three constitutions from `constitutions/` into `~/.agent-hats/`:

- missing: copied in (`installed <path>`);
- identical to the repo copy: left alone (`unchanged <path>`);
- different (you edited it, or the repo copy changed): the existing file is saved to
  `<mode>.md.bak`, the repo copy is installed, and a `notice:` line names the backup.

To keep a local edit, merge it back from the `.bak` after re-installing, or edit
`constitutions/<mode>.md` in your checkout instead.

Requires `bash` (Windows Git Bash works) and, depending on the kind, Claude Code (`claude`) or
GitHub Copilot CLI (`copilot`) on `PATH`. `jq` is optional (see [Claude first run](#claude-first-run),
[Folder trust](#folder-trust) and [Model and effort](#model-and-effort)).

## Usage

```sh
hat <mode> [<nickname>] [--kind <claude|copilot>] [--backend <nickname>] \
    [--model <model>] [--effort <effort>] [--] [agent args...]
```

`<mode>` names the constitution `~/.agent-hats/<mode>.md`: `explore`, `live`, `adhoc`, or one of
[your own](#your-own-hats). Each mode and kind gets its own config home,
`~/.agent-hats/homes/<mode>-<kind>`.

## Kinds

The agent CLI is chosen by `--kind <claude|copilot>` (`hat explore --kind copilot`, or
`--kind=copilot`), else by the `HAT_KIND` environment variable, else by the kind of the selected
[backend](#model-and-effort), else `claude`. The flag wins when both are set. Any other value exits
non-zero naming the accepted values. The kind is part of the config home, so a Claude and a Copilot agent for the same mode never share a home.

| kind      | home variable       | prompt file in home       | config home (e.g. `explore`)          |
|-----------|---------------------|---------------------------|---------------------------------------|
| `claude`  | `CLAUDE_CONFIG_DIR` | `CLAUDE.md`               | `~/.agent-hats/homes/explore-claude`  |
| `copilot` | `COPILOT_HOME`      | `copilot-instructions.md` | `~/.agent-hats/homes/explore-copilot` |

Each launch:

1. Requires the constitution `~/.agent-hats/<mode>.md`; if it is missing, exits non-zero
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
the agent invocation verbatim. A first bare word is the backend nickname, so `hat live ccz` means
`hat live --backend ccz`, unless `--backend` was already given. A later bare word starts the agent
arguments, and so does `--`, which is dropped. To pass an initial prompt, put it after the nickname
or after `--`:

```sh
hat live ccz --effort high   # backend ccz, effort high
hat live ccz "fix the bug"   # backend ccz, initial prompt
hat live -- "fix the bug"    # default backend, initial prompt
```

### Model and effort

`<model>` and `<effort>` are each resolved separately, first match wins:

1. `--model` / `--effort`, else `HAT_MODEL` / `HAT_EFFORT`.
2. The backend entry selected by `--backend <nickname>` (else `HAT_BACKEND`), looked up in
   `~/.agent-hats/backends.json`, then in mat's `~/.config/mat/backends.json`.
3. Built-in defaults: `opus[1m]` / `medium` for `claude`, `gpt-5.5` / `medium` for `copilot`.

Both tables are optional and share mat's schema:

```json
{"backends": [
  {"nickname": "sonnet", "kind": "claude", "default_model": "sonnet[1m]", "default_effort": "high"}
]}
```

Only `nickname`, `kind`, `default_model`, `default_effort` and (for `claude`, see
[Claude token](#claude-token)) `auth_var` and `base_url_var` are read; other fields (`config_dir`, `prompt_file`, …)
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
every mode's home. A backend whose `base_url_var` names an environment variable (a third-party
Anthropic-compatible endpoint) gets it as `ANTHROPIC_BASE_URL`; if that variable is empty the launch
exits non-zero, so the backend's key is never sent to Anthropic. If the token variable is empty and neither `ANTHROPIC_AUTH_TOKEN` nor
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

`~/.agent-hats/<mode>.md` (`explore.md`, `live.md`, `adhoc.md`) is one self-contained
Markdown file per mode. It becomes that mode's user-level prompt file (`CLAUDE.md` or
`copilot-instructions.md`). There is no composition or shared-snippet layer; the three files
repeat each other on purpose. The roles are listed at the [top](#agent-hats).

Each file has a `## Role boundary` section stating what the mode does and must not do.

### Your own hats

Write `~/.agent-hats/<mode>.md` and run `hat <mode>`; nothing else to register. For example,
`~/.agent-hats/code-review.md` makes `hat code-review`, with its own home
`~/.agent-hats/homes/code-review-claude`. A mode name uses letters, digits, `-` and `_`, and
starts with a letter or digit; anything else exits non-zero. Start from one of the shipped
constitutions and keep a `## Role boundary` section. `install.sh` only manages the three shipped
files and never touches yours.

## Tests

```sh
bash test/run.sh
```

## License

[MIT](LICENSE)
