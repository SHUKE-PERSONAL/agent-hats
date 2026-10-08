---
marp: true
theme: default
paginate: true
size: 16:9
title: Same Agent, Different Hats
style: |
  :root { --accent: #0f766e; --muted: #64748b; --soft: #f0fdfa; }
  section { font-family: "Inter", "Segoe UI", "Helvetica Neue", sans-serif; font-size: 32px; padding: 56px 72px; color: #0f172a; }
  h1 { color: var(--accent); font-size: 54px; margin-bottom: 0.3em; }
  h2 { color: var(--accent); font-size: 42px; margin-bottom: 0.6em; }
  strong { color: var(--accent); }
  em { color: var(--muted); font-style: normal; }
  code { background: var(--soft); color: #134e4a; }
  pre { background: #0f172a; border-radius: 8px; font-size: 30px; padding: 18px 24px; }
  pre code, pre code span { background: transparent !important; color: #e2e8f0 !important; }
  pre code .hljs-comment { color: #94a3b8 !important; }
  pre code .hljs-string { color: #5eead4 !important; }
  pre code .hljs-attr { color: #fcd34d !important; }
  section.lead { justify-content: center; }
  section.big { justify-content: center; text-align: center; }
  section.big h1 { font-size: 60px; }
  .cols { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
  .card { background: var(--soft); border-left: 6px solid var(--accent); border-radius: 8px; padding: 14px 24px; }
  .card.old { background: #f8fafc; border-left-color: #94a3b8; }
  .card p { margin: 0.25em 0; }
  table { font-size: 30px; }
  section.dense pre { font-size: 21px; padding: 14px 20px; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

![w:300](../../../assets/logo.svg)

# Same Agent, Different Hats

My everyday AI dev setup

<!--
~30s
Hello, everyone.
Today I'd like to show you the setup I use every day.
We already use skills and MCPs to ease our work, but most of us still run bare `claude`.
-->

---

## What makes a good harness?

Claude Code and Copilot CLI already are — **with the right settings**

- **A custom home** — one role, one config
- **Hooks and skills** — the routine runs itself
- **A constitution** — clear rules, no babysitting

*Micro-managed agents get lazy: they ask about everything.*

<!--
~2 min
A couple of weeks ago our Director asked me: what makes a good harness?

My answer: the ones we already have. Claude Code and GitHub Copilot CLI are good harnesses — with the right settings. Both support a custom config home, hooks and skills very well. With the right settings, they get work done on their own, without babysitting.
I'm not saying babysitting is bad. But with a constitution written for one kind of task, an agent working on its own can do more — and do it better — than when we babysit it all the time.
What I've found: when we micro-manage an agent, it gets lazy. It asks us to decide everything, even questions with obvious answers. That wastes our time, and it makes us angry.

There are two ways to get things done with agents. The first way: you drive, the agent assists. Just like what we did with Cursor in the early days. Many people insist on this way, as it gives us a feeling of "I still control everything". That isn't bad, but it is not that efficient. We deliver things a little bit quicker than before, but not that much faster.

The other way is different: we give a well-defined ticket to a delivery agent, and it does the planning, the plan review, the implementation, the implementation review, and creates the PR on its own. That's the way I take.

You might ask: how do you control the code quality? By talking with a pair-review agent, I find the defects the delivery agent missed, and I fully understand the outcome. By doing local testing with a tester agent, I gain confidence in the outcome.

By the way, our Claude subscription is usually a basic one — it doesn't last long under heavy use.
A few small changes make it last longer, behave better, and do different jobs well.
So, next, I'll show you the settings I use, why they work, and how they work.
-->

---

## Five tweaks over bare `claude`

1. Log in once
2. Cap the context window
3. One role, one constitution
4. Wear a hat
5. One subscription, a whole team

<!--
~30s
The first three work with plain Claude Code today. The fourth packages them into one command: `hat`. The fifth builds on `hat`: one subscription, a whole team.
-->

---

## 1 — Log in once

```sh
claude setup-token    # once

# in ~/.bashrc
export CLAUDE_CODE_OAUTH_TOKEN=<token>
export COPILOT_GITHUB_TOKEN=github_pat_...
```

<!--
~1 min
`claude setup-token` gives you a long-lived OAuth token for your subscription. Put it in your shell profile, and Claude Code stops asking you to log in — it just works.
Copilot works the same way. In GitHub, Settings → Developer settings, create a fine-grained personal access token with only the "Copilot Requests" permission. I'll show you how.
Treat both like passwords — they are your subscriptions. Never commit them, never paste them into a chat.
-->

---

## 2 — Cap the context window

```text
Opus 5.5 | dfx@feature/mt-12345-axo | 120k/256k (46%) | effort: med
```

Bigger context ≠ better answers

<!--
~1.5 min
A 1M context window is a good thing — why do we cap it? You might ask.
Every time we send a message to Claude, and on every tool call, Claude sends the whole conversation to the server.
A 1M-token session that never compacts burns through your usage limit, and quality drops as the context fills with stale material.
I cap it at 256K: set CLAUDE_CODE_AUTO_COMPACT_WINDOW=256000, and Claude Code compacts the session when the context approaches the limit I set. Even a small subscription like ours lasts much longer.
The status line — it ships with agent-hats — makes it visible: tokens held against the 256K cap, not the 1M window — the percentage is how much of the cap you've used.
Sure, you can raise it higher — 300K, 350K — but I don't recommend going past 400K. A long context looks sweet and tastes bitter: beyond 400K, Claude gets noticeably dumber and eats the 5-hour limit much faster.
Yes, we can always call /compact manually, but we humans are good at forgetting things.
-->

---

## 3 — One role, one constitution

<div class="cols">
<div class="card old">

**Bare `claude`**
One `~/.claude/CLAUDE.md`
for every job

</div>
<div class="card">

**Per role**
One constitution per role
Its own config home

</div>
</div>

<!--
~1.5 min
Basically, a constitution is a rules file for the agent: what it should do, what it shouldn't, and what it must not do.
With bare Claude, one global CLAUDE.md tries to serve every job — it easily grows big, and fast. The bad thing is, agents don't follow a long constitution well.
Instead: one constitution per role, each in its own config home (CLAUDE_CONFIG_DIR for Claude, COPILOT_HOME for Copilot). You get tighter control, and each file stays small.
One catch: empty your default `~/.claude/CLAUDE.md`. Claude always loads it first, even when started with a custom home.
So what Claude actually receives is: the global CLAUDE.md (kept empty), plus the role's constitution, plus the repo's own CLAUDE.md. That's why a constitution should be short and to the point — I keep mine under 15K characters.
-->

---

<!-- _class: dense -->

## Without hats: a custom home by hand

```sh
mkdir -p ~/roles/live/skills
cp ~/my-rules/live.md ~/roles/live/CLAUDE.md
ln -s ~/.claude/skills/* ~/roles/live/skills/   # skills don't follow you

CLAUDE_CONFIG_DIR=~/roles/live \
CLAUDE_CODE_AUTO_COMPACT_WINDOW=256000 \
ANTHROPIC_AUTH_TOKEN=$CLAUDE_CODE_OAUTH_TOKEN \
  claude --model='opus[1m]' --effort medium --dangerously-skip-permissions
```

…then onboarding, bypass warning, folder trust per repo.
**Per role. Again for Copilot.**

<!--
~1 min
Tweaks 1 to 3 all work with plain Claude Code. Here's what that looks like for one role, by hand.
A fresh home is a fresh install: onboarding, theme, the bypass-permissions warning, and the trust dialog again in every repo you open.
Your personal skills live in ~/.claude/skills, so the new home doesn't see them — you link them in yourself. On Windows, Git Bash's ln -s silently makes a copy by default, so later edits to your skills never arrive. A real symlink needs two things: Developer Mode turned on (Settings → System → For developers), and `export MSYS=winsymlinks:nativestrict` in your shell. Without Developer Mode, use a junction instead: `mklink /J`.
The token line is a trap: if the home ever ran /login, a stale .credentials.json beats CLAUDE_CODE_OAUTH_TOKEN, so you pass it as ANTHROPIC_AUTH_TOKEN instead.
And the status line, a different model and context cap per job… Multiply by four roles, then do it all again for Copilot: COPILOT_HOME, copilot-instructions.md, its own trust list.
It works, but every line here is something `hat` now does for you on each launch.
-->

---

## 4 — agent-hats

![w:260](../../../assets/logo.svg)

| hat | role |
|---|---|
| `explore` | investigate, write tickets — no code |
| `live` | pair with me on small changes |
| `adhoc` | deliver one ticket, then stop |
| `audit` | review merged work, file tickets — no fixes |

<!--
~1.5 min
agent-hats packages tweaks 1 to 3 — everything on the previous slide — into one command. Same harness, different hat.
Hats also get skills: explore and audit bring a ticket self-critique skill, and live links your personal skills from ~/.claude/skills — with a junction on Windows when symlinks aren't allowed, so no admin rights needed.
One thing it doesn't carry over: user-scope MCP servers. A repo's .mcp.json works in every hat; add a personal server to a hat with `CLAUDE_CONFIG_DIR=~/.agent-hats/homes/live-claude claude mcp add …`.
- explore: reads code, reproduces bugs, finds root causes, and writes a ticket a delivery agent can work from. It is not allowed to write delivery code.
- live: the hands-on generalist — what you already do with Claude every day. I use it for smaller changes; when the scope becomes bigger, I use the explore hat to draft a ticket first.
- adhoc: the only delivery agent. Give it a well-defined ticket: it plans, reviews its own plan, implements, critiques its own implementation, tests locally, and opens a draft PR. Plan, implementation, review and test are each written to the ticket folder, so a tester can see a week later how it was checked.
- audit: this agent is for QA people. It works on its own; you don't need to talk to it. Run hat audit, and it starts checking recently merged PRs and the code around them. It files tickets and never touches the code. The first time I ran it on the DFX repo, it caught a production bug.
Every hat follows its constitution. By default, none of them merges, marks a PR ready, deploys, or touches JIRA — the draft PR waits for me. You can easily extend it by simply changing its constitution file or giving it more tools.
Plain bash: Linux, macOS, and Windows Git Bash.
-->

---

## Install

```sh
git clone https://github.com/SHUKE-PERSONAL/agent-hats.git
cd agent-hats && ./install.sh
export PATH="$HOME/.local/bin:$PATH"   # if needed
```

Needs: `bash`, `claude` or `copilot` · optional `jq`

<!--
~45s
The installer writes one command, `hat`, into ~/.local/bin, and copies any of the four constitutions you don't have yet into ~/.agent-hats/.
It also drops in an example ~/.agent-hats/backends.json — the one on the next slide — unless you already have one.
Re-running it is safe: it never overwrites a constitution or your backends.json, so your edits stay. To take a newer copy from the repo, merge it in yourself, or delete yours and re-run.
The installer doesn't touch your .bashrc. If `hat` says "command not found", add ~/.local/bin to your PATH — on macOS and Git Bash it isn't there by default.
On Windows, Git Bash is enough.

By the way, different deployments can have different constitution files. For example, on your own PC, for your side projects, you can allow the delivery agent to merge the PR when CI gives a green light. It is totally up to you.
-->

---

<!-- _class: dense -->

## 5 — One subscription, a whole team

```json
// ~/.agent-hats/backends.json
{"backends": [
  {"nickname": "easy", "kind": "claude", "context_window_size": "256k",
   "default_model": "opus[1m]", "default_effort": "medium"},
  {"nickname": "sonnet", "kind": "claude", "context_window_size": "256k",
   "default_model": "sonnet[1m]", "default_effort": "high"},
  {"nickname": "hard", "kind": "claude", "context_window_size": "400k",
   "default_model": "opus[1m]", "default_effort": "high"},
  {"nickname": "daily", "kind": "copilot",
   "default_model": "gpt-6-luna", "default_effort": "max"},
  {"nickname": "sol", "kind": "copilot",
   "default_model": "gpt-6.1-sol", "default_effort": "high"},
  {"nickname": "astra", "kind": "copilot",
   "default_model": "gpt-6-astra", "default_effort": "medium"}
]}
```

<!--
~1.5 min
The installer gave you this file, ~/.agent-hats/backends.json. It turns one subscription into a team, with one nickname per "team member": which CLI, which model, how hard it thinks, how much context it keeps.
With a strong model like Opus 5.5, normally medium effort is enough for everyday work. Save high or xhigh for the genuinely hard problems — a tricky root cause, a risky refactor — and give that member a bigger context window too.
Same subscription, same token budget — but now it behaves like a small team with different strengths.
Copilot fits in the same table: "kind": "copilot" makes that nickname launch Copilot CLI instead of Claude. That matters here — most of us already have a Copilot licence. An entry can also name its token variable with "auth_var" — handy for a second account.
I haven't found a way to set Copilot's context window from the command line; we can always change it in Copilot's UI. Model and effort are the main levers anyway.
-->

---

## Use

```sh
hat explore                 # create or refine a ticket
hat live                    # pair on a small change
hat live hard               # same hat, "hard" backend
hat adhoc -- "do MT-12345"  # deliver one ticket
hat explore astra           # Copilot CLI, gpt-6-astra
hat audit                   # one audit pass, tickets only
```

<!--
~1.5 min — live demo here if time allows; have a recording as backup.
The first word after the hat is a backend nickname from the table; its kind decides whether Claude or Copilot starts — no extra flag. With no nickname you get Opus, high effort, 256K. Anything after `--` is the initial prompt.
A fresh home starts without onboarding or trust prompts — the launcher pre-answers them.
-->

---

## A typical day

`hat explore` → ticket → `hat adhoc` → local test → my review → peer review

<!--
~1 min
Explore turns a fuzzy JIRA ticket into a well-defined, precise issue: problem, approach, clear acceptance criteria. It writes it to ~/.agent-hats/tickets/<KEY>/ and prints the path. I check it.
I open a second tab, start `hat adhoc`, and paste that path. Adhoc delivers against the ticket, and I test it locally with a live agent.
I review the diff — with a pair-review skill — before anything leaves my machine. Only then do I mark the draft PR ready for the normal peer review.
Nothing in our process is skipped. The agent just does the legwork.
-->

---

## Make your own hat

```sh
cp ~/.agent-hats/live.md ~/.agent-hats/tester.md
# edit the role boundary, then:
hat tester
```

<!--
~45s
A hat is just a constitution. Any Markdown file in ~/.agent-hats/ is a hat — nothing to register.
`tester.md` gives you `hat tester`, with its own config home.
Ideas: a devops hat that knows our pipelines and stays read-only on infrastructure; a tester hat that writes test plans and drives the UI with Playwright; a code-review hat.
Start from a shipped constitution and keep its "Role boundary" section — that's what keeps the role honest.
The installer only manages the four shipped hats; it never touches yours.
-->

---

<!-- _class: big -->
<!-- _paginate: false -->

# Start small

**1.** `claude setup-token`
**2.** `./install.sh`, then `hat live`
**3.** Edit `~/.agent-hats/backends.json` (optional)

*Thank you!*

<!--
~30s
You don't need all of it on day one. A token takes a minute and pays off immediately.
Then try one hat. I'd start with live: you can use your own CLAUDE.md as ~/.agent-hats/live.md. Back up your ~/.claude/CLAUDE.md, then empty it, and run `hat live`.
The repo is public and MIT-licensed; issues and pull requests welcome.
-->
