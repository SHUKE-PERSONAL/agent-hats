<p align="center"><img src="assets/logo.svg" alt="agent-hats logo: a pith helmet, a hard hat and a cap" width="360"></p>

# agent-hats

Same harness, different hat. `hat explore`, `hat live`, `hat adhoc` and `hat audit` start Claude Code or
GitHub Copilot CLI wearing a hat — and a hat is more than a name: each one carries a
[constitution](#constitution-contract), a rules file that says what the role does and must not do.
That is why one agent, under different hats, does different jobs well. Each hat also gets its own
config home, so the roles never bleed into each other. Plain `bash`; runs on Linux, macOS and
Windows Git Bash.

Four hats ship with the repo; any Markdown file you drop into `~/.agent-hats/` is another
(see [Your own hats](#your-own-hats)).

| hat          | role                                                                 |
|--------------|----------------------------------------------------------------------|
| `explore`    | investigates and writes tickets; does not write delivery code        |
| `live`       | hands-on generalist: small fixes, tested, pushed as a DRAFT PR       |
| `adhoc`      | delivers one ticket to a DRAFT PR, with a written plan/review/test trail |
| `audit`      | one bounded pass over merged PRs and the code; writes tickets, never fixes |

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

It also installs the four constitutions from `constitutions/` into `~/.agent-hats/`:

- missing: copied in (`installed <path>`);
- identical to the repo copy: left alone (`unchanged <path>`);
- different (you edited it, or the repo copy changed): left alone (`kept <path> (differs from
  <repo copy>)`).

Install never overwrites a constitution, so your edits are safe. To take a newer repo copy,
merge it in yourself or delete `~/.agent-hats/<mode>.md` and re-run `install.sh`.

Requires `bash` (Windows Git Bash works) and, depending on the kind, Claude Code (`claude`) or
GitHub Copilot CLI (`copilot`) on `PATH`. `jq` is optional (see [Claude first run](#claude-first-run),
[Folder trust](#folder-trust) and [Model and effort](#model-and-effort)).

## Usage

```sh
hat <mode> [<nickname>] [--kind <claude|copilot>] [--backend <nickname>] \
    [--model <model>] [--effort <effort>] [--] [agent args...]
```

`<mode>` names the constitution `~/.agent-hats/<mode>.md`: `explore`, `live`, `adhoc`, `audit`, or one of
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
   CLAUDE_CONFIG_DIR=<home> CLAUDE_CODE_AUTO_COMPACT_WINDOW=<window> ANTHROPIC_AUTH_TOKEN=<token> \
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

`hat audit` needs no request, so with no agent arguments it starts with the prompt
`Run one audit pass.` (for `copilot`, via `-i`). Any argument replaces it: `hat audit -- "audit PR #7"`.

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

Only `nickname`, `kind`, `default_model`, `default_effort` and, for `claude`, `auth_var`,
`base_url_var` (see [Claude token](#claude-token)) and `context_window_size` (see
[Context window](#context-window)) are read; other fields (`config_dir`, `prompt_file`, …)
are ignored, and an empty or missing model or effort falls to the
built-in default. The entry's `kind` selects the kind unless one is given explicitly; an explicit
kind that differs, or an entry kind other than `claude`/`copilot`, exits non-zero.

Without `--backend` no table is read. The tables are only ever read, never written, and a lookup
is best-effort: without `jq`, or when no table exists, the launcher warns and uses the built-in
defaults; an unreadable or malformed table is skipped with a warning. A nickname that no readable
table contains exits non-zero naming it.

### Context window

Claude compacts the conversation once it holds `CLAUDE_CODE_AUTO_COMPACT_WINDOW` tokens. The
launcher sets it from the backend's `context_window_size` — an integer, optionally with a `k` or
`m` suffix (`"350k"`, `"1m"`, `150000`) — else to `256000`, well below the 1M window, so each turn
re-sends less and a subscription lasts longer. An invalid value warns and uses `256000`. Any value
already in your environment is replaced.

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

### Status line

With `jq`, the launcher also sets `statusLine` in `<home>/settings.json` to run `bin/hat-statusline`
from this checkout, unless the home already has a status line of its own (one pointing at an older
`hat-statusline` path is repointed). It shows

```
Opus 5.5 | my-repo@main (+71 -10) | 120k/256k (46%) | effort: med
```

— model, folder and branch with uncommitted line counts, tokens held against the compact window
(not the model's full window, so the percentage is the runway left before compaction), and effort.
The status line itself needs `jq`; without it, it prints `Claude`.

### Skills

Each home has its own `skills/` folder, so skills in `~/.claude/skills` or `~/.copilot/skills`
are not seen by a hat by default. On every launch:

- the skills in this checkout's `skills/` whose `hats` file lists the mode are copied into the
  home, replacing the previous copy — `explore` and `audit` get `ticket-self-critique`;
- `live` also links each of your personal skills (`~/.claude/skills/*` for `claude`,
  `~/.copilot/skills/*` for `copilot`) into its home, unless the home already has a skill of
  that name.

On Windows Git Bash, `ln -s` makes a copy unless native symlinks are enabled, so a personal skill
edited later is not picked up; delete it from the home to re-link it.

MCP servers are not carried over: user-scope servers live in the default home's `.claude.json`,
which a hat home does not read. A repo's `.mcp.json` works in every hat; add a user-scope
server to a hat with `CLAUDE_CONFIG_DIR=~/.agent-hats/homes/live-claude claude mcp add …`.

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

`~/.agent-hats/<mode>.md` (`explore.md`, `live.md`, `adhoc.md`, `audit.md`) is one self-contained
Markdown file per mode. It becomes that mode's user-level prompt file (`CLAUDE.md` or
`copilot-instructions.md`). There is no composition or shared-snippet layer; the four files
repeat each other on purpose. The roles are listed at the [top](#agent-hats).

Each file has a `## Role boundary` section stating what the mode does and must not do.

Each shipped file also opens with a `## Team conventions` block — ticket key, branch name,
commit and PR prefix, protected branches — written with placeholders (`ABC-1234`,
`feature/<key>`). Edit it once to match your team.

None of the hats merges, marks a PR ready, or updates JIRA; `live` and `adhoc` stop at a DRAFT
PR for a human to review.

### Ticket folders

The shipped hats keep their written record outside the repo, one folder per ticket:

```
~/.agent-hats/tickets/ABC-1234/
  abc-1234-issue.md      explore or audit: the ticket
  abc-1234-plan.md       adhoc
  abc-1234-impl.md       adhoc
  abc-1234-review.md     adhoc: each acceptance criterion → how it was verified
  abc-1234-test.md       adhoc, live: local test record
  artifacts/             screenshots, logs
```

Files are write-once; a redone stage is `-v2`, `-v3`, …. `explore` ends by printing the
ticket's absolute path — paste it into a `hat adhoc` session to deliver it.

### Your own hats

Write `~/.agent-hats/<mode>.md` and run `hat <mode>`; nothing else to register. For example,
`~/.agent-hats/code-review.md` makes `hat code-review`, with its own home
`~/.agent-hats/homes/code-review-claude`. A mode name uses letters, digits, `-` and `_`, and
starts with a letter or digit; anything else exits non-zero. Start from one of the shipped
constitutions and keep a `## Role boundary` section. `install.sh` only manages the four shipped
files and never touches yours.

## Tests

```sh
bash test/run.sh
```

## License

[MIT](LICENSE)

`constitutions/audit.md`, `skills/ticket-self-critique` and `bin/hat-statusline` are adapted from the
my-ai-team framework and released here under the same MIT license by their copyright holder.
