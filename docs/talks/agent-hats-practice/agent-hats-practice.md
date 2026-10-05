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
Today I'd like to show you the setup I use every day.
We already use skills and MCP servers to ease our work, but most of us still run bare `claude`. And our Claude subscription is usually a basic one — it doesn't last long under heavy use.
A few small changes make it last longer, behave better, and do different jobs well.
-->

---

## Five tweaks over bare `claude`

1. Log in once
2. Cap the context window
3. One subscription, a whole team
4. One role, one constitution
5. Wear a hat

<!--
~30s
The first four work with plain Claude Code today. The fifth packages them into one command: `hat`.
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
Copilot works the same way. In GitHub, Settings → Developer settings, create a fine-grained personal access token with only the "Copilot Requests" permission. I'll show you how. (Classic `ghp_` tokens don't work.)
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
Every turn re-sends the whole conversation. A 1M-token session that never compacts burns through your usage limit, and quality drops as the context fills with stale material.
I cap it at 256K: Claude Code compacts the session when the context approaches 256K. Even a small subscription like ours lasts much longer.
The status line makes it visible: tokens held against the 256K cap, not the 1M window — the percentage is how much of the cap you've used.
You can raise it, but I don't recommend going past 400K. A long context looks sweet and tastes bitter: beyond 400K, Claude gets noticeably dumber and eats the 5-hour limit much faster.
-->

---

<!-- _class: dense -->

## 3 — One subscription, a whole team

```json
{"backends": [
  {"nickname": "claude", "kind": "claude", "context_window_size": "256k",
   "default_model": "opus[1m]", "default_effort": "medium"},
  {"nickname": "sonnet", "kind": "claude", "context_window_size": "256k",
   "default_model": "sonnet[1m]", "default_effort": "high"},
  {"nickname": "hard", "kind": "claude", "context_window_size": "400k",
   "default_model": "opus[1m]", "default_effort": "high"},
  {"nickname": "pilotd", "kind": "copilot",
   "default_model": "gpt-6-luna", "default_effort": "max"},
  {"nickname": "piloth", "kind": "copilot",
   "default_model": "gpt-6.1-sol", "default_effort": "high"},
  {"nickname": "pilota", "kind": "copilot",
   "default_model": "gpt-6-astra", "default_effort": "medium"}
]}
```

<!--
~1.5 min
How do you set this up? One table, ~/.agent-hats/backends.json, with one nickname per "team member": which CLI, which model, how hard it thinks, how much context it keeps.
With a strong model like Opus 5.5, medium effort is enough for everyday work. Save high or xhigh for the genuinely hard problems — a tricky root cause, a risky refactor — and give that member a bigger context window too.
Same subscription, same token budget — but now it behaves like a small team with different strengths.
Copilot fits in the same table: "kind": "copilot" makes that nickname launch Copilot CLI instead of Claude. That matters here — most of us already have a Copilot licence.
I haven't found a way to set Copilot's context window from the command line; you can still pick it in Copilot's UI. Model and effort are the main levers anyway.
The table comes from a side project of mine, my-ai-team — another talk, if you're interested. Neither Claude Code nor Copilot reads it directly; the next slides show what does.
-->

---

## 4 — One role, one constitution

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
A constitution is a standing rules file for the agent: what this role does, and what it must not do.
With bare Claude, one global CLAUDE.md tries to serve every job — investigating, coding, one-off tasks — and the rules fight each other.
Instead: one constitution per role, each in its own config home (CLAUDE_CONFIG_DIR for Claude, COPILOT_HOME for Copilot). You get tighter control, and each file stays small.
One catch: empty your default `~/.claude/CLAUDE.md`. Claude always loads it first, even when started with a custom home.
So what Claude actually receives is: the global CLAUDE.md (kept empty), plus the role's constitution, plus the repo's own CLAUDE.md. That's why a constitution should be short and to the point — I keep mine under 15K characters.
-->

---

## 5 — agent-hats

![w:260](../../../assets/logo.svg)

| hat | role |
|---|---|
| `explore` | investigate, write tickets — no code |
| `live` | pair with me on small changes |
| `adhoc` | deliver one ticket, then stop |

<!--
~1.5 min
agent-hats packages tweaks 1 to 4 into one command. Same harness, different hat.
- explore: reads code, reproduces bugs, finds root causes, and writes a ticket a delivery agent can work from. It may not write delivery code.
- live: the hands-on generalist — what you already do with Claude every day. I use it for smaller changes; when the scope grows, I have explore draft a proper ticket first.
- adhoc: delivery. Give it a well-defined ticket: it plans, reviews its own plan, implements, critiques its own diff, tests locally, and opens a draft PR. Plan, implementation, review and test are each written to the ticket folder, so a tester can see a week later how it was checked.
Every hat follows its constitution. None of them merges, marks a PR ready, deploys, or touches JIRA — the draft PR waits for me.
Plain bash: Linux, macOS, and Windows Git Bash.
-->

---

## Install

```sh
git clone https://github.com/SHUKE-PERSONAL/agent-hats.git
cd agent-hats && ./install.sh
```

Needs: `bash`, `claude` or `copilot` · optional `jq`

<!--
~45s
The installer writes one command, `hat`, into ~/.local/bin, and copies the three constitutions into ~/.agent-hats/.
Re-running it is safe: if a constitution has changed, your old copy is backed up to .bak first.
On Windows, Git Bash is enough.
-->

---

## Use

```sh
hat explore                 # shape a ticket
hat live                    # pair on a small change
hat live hard               # same hat, "hard" backend
hat adhoc -- "do MT-12345"  # deliver one ticket
hat explore pilota          # same hat, Copilot CLI
```

<!--
~1.5 min — live demo here if time allows; have a recording as backup.
The first word after the hat is a backend nickname from the table; its kind decides whether Claude or Copilot starts — no extra flag. With no nickname you get Opus, medium effort, 256K. Anything after `--` is the initial prompt.
A fresh home starts without onboarding or trust prompts — the launcher pre-answers them.
-->

---

## A typical day

`hat explore` → ticket → `hat adhoc` → local test → my review → peer review

<!--
~1 min
Explore turns a fuzzy JIRA ticket into something precise: problem, approach, acceptance criteria. It writes it to ~/.agent-hats/tickets/<KEY>/ and prints the path. I check it.
I open a second tab, start `hat adhoc`, and paste that path. Adhoc delivers against the ticket, and I test it locally.
I review the diff — with the agent's help — before anything leaves my machine. Only then do I mark the draft PR ready for the normal peer review.
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
The installer only manages the three shipped hats; it never touches yours.
-->

---

<!-- _class: big -->
<!-- _paginate: false -->

# Start small

**1.** `claude setup-token`
**2.** Edit `~/.agent-hats/backends.json`
**3.** Run `hat live`

*Questions?*

<!--
~30s + Q&A
You don't need all of it on day one. A token and a backends table take five minutes and pay off immediately.
Then try one hat. I'd start with live: move your own CLAUDE.md to ~/.agent-hats/live.md, empty ~/.claude/CLAUDE.md, and run `hat live`.
The repo is public and MIT-licensed; issues and pull requests welcome.
-->
