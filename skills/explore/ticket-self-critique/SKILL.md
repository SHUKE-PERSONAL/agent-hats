---
name: ticket-self-critique
description: >
  Re-read a ticket you just wrote and find what a delivery agent would trip over.
  Invoke after writing or revising a ticket file, before handing its path over.
---

**Capture gates — should this ticket exist?** Answer these before the body questions. A
finding that fails a gate does not become a delivery ticket: fold it into the ticket that
already owns it, or report it in your reply with no ticket at all. A ticket the operator asked
for clears Value on that request.

- **Value.** Concrete user or operator impact, a reproducible recurring failure, a security
  exposure, or a direct acceptance- or merge-blocking consequence. A smell you happened to
  notice is not value.
- **Distinctness.** A new root cause — not a duplicate, not a symptom of an existing ticket,
  not an alternative response to one.
- **Feasibility and target fidelity.** The permissions, APIs, and runtime capabilities the
  approach depends on are verified, and the exact affected branch, revision, or object is
  named. Never substitute the default branch, or an assumed platform feature, for the real
  target.
- **Actionability.** One bounded problem and one proposed outcome. An unresolved A/B choice is
  not a delivery ticket: write it as a decision for the operator, with the verified options.

Then re-read the body as an outsider and answer each honestly:

- Does the problem statement stand alone for someone outside this conversation?
- Is the approach root-cause, or a patch over the symptom? Is there a more reasonable
  alternative you haven't weighed?
- Does each acceptance criterion give an observable outcome plus a concrete check (command,
  log, query, screen) a delivery agent can pass or fail in one pass without asking? Ban
  `improve`, `optimize`, `properly`, `correctly`, `robustly`, `ensure` unless paired with a
  threshold.
- Where the behavior has edge conditions — invalid input, unavailable dependency, conflicting
  state — on which a reasonable delivery agent could choose differently, is each decision
  stated as an acceptance criterion? (Skip for pure docs, refactors, formatting.)
- **Scope.** Default to one cause, one owner, one reviewable PR. Split only for genuinely
  independent root causes or jointly unverifiable criteria, in dependency order, each later
  ticket naming the one it depends on. A shared cause never justifies an unreviewable scope;
  a cohesive one never needs an artificial split.
- Did anything from the investigation fail to make the ticket?
- Every open question left to the operator: a genuine value, priority, or risk call they own,
  or one you could answer by reading the code? Answer the latter yourself first.
- Does the body still carry process — prior debate, rejected framing, narration — that
  delivery does not need? Strip it; keep anything that constrains delivery as a present-tense
  constraint or non-goal.
- For a behavior change (new, altered, or removed user- or operator-facing behavior): do the
  acceptance criteria include updating the affected docs?
- If the fix or its verification needs a specific platform (Windows, a device, a browser), does
  the ticket say so?

If any answer is "no" or "not really", write the next version of the ticket file now
(`-v2`, `-v3`, …). A weak ticket wastes delivery time re-deriving what was settled here.

**Aim for the middle level:**

- **Raw report** — a thin symptom or desire. Valid intake, not delivery-ready.
- **Delivery-ready ticket** (the target) — standalone problem, the conclusion, a concrete
  approach, a verifiable acceptance boundary, explicit non-goals. A delivery agent acts on it
  without re-deriving the design.
- **Plan** — file-by-file steps, edit order. That is delivery's job. Before you finish, read
  it as the agent who will deliver it: what would make you frown? Keep the ticket to *what*
  and *why*, never *how*.

**Worked examples:**

- **Target unverified.** A test run demonstrably fails, but you have not established whether
  it ran the branch or the default branch. Value passes, target fidelity does not: say so in
  the ticket, and do not call it delivery-ready until the real target is confirmed.
- **Alternative response.** A second ticket proposes a different fix for a problem an existing
  ticket already owns. Distinctness fails: fold the option into that ticket.
- **Platform limitation.** The approach needs a permission or API the target does not have.
  Feasibility fails: report it as a blocker or decision, never as a set of alternative tickets.
- **Preserved path.** A concrete regression, a security finding, or a merge blocker that clears
  all four gates is still written up as a delivery-ready ticket. The gates cut noise, not real
  findings.

Finish by printing the current ticket file's absolute path on its own line.
