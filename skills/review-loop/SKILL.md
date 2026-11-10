---
name: review-loop
description: Use this skill when running iterative code review to a fixed point — repeatedly spawning fresh reviewer subagents, acting on their findings, and re-reviewing until nothing new turns up. Also covers the mechanics of waiting on long-running background agents without burning the session on useless polling. Activate whenever the user asks for review rounds, an unbiased or independent review, review "until it converges" or "until a fixed point", or when you are about to wait on a background agent.
---

# Iterative Review to a Fixed Point

A review loop is: spawn a **fresh** reviewer with no memory of previous rounds →
act on what it finds → spawn another fresh reviewer → stop when a round
surfaces nothing you haven't already considered.

It works because self-review goes blind. Having just written or defended a
piece of code, you are the worst available reviewer of it. A reviewer that has
never seen your reasoning will question things you stopped questioning rounds
ago. That blindness compounds across iterations: code that several agents have
already "refined" accumulates confident, wrong comments and fixes that
introduced their own bugs.

## The waiting trap — read this before spawning anything

The single most expensive failure in this workflow is not a bad review. It is
**polling a dead agent**.

A background agent can wedge — hit a context limit, die on an API error, stall
— while the orchestrator's bookkeeping still reports it as `running`. If your
idea of "check on it" is to call the agent-listing tool again, you will see
`running` forever and conclude, every single time, that you should wait a bit
more. Dozens of turns can disappear this way with zero work done.

**`running` in a status listing is not evidence of progress.** It is a flag
someone set when the agent started and nobody cleared. Progress is evidence of
progress.

### Check liveness, not status

Agents write a transcript file as they work. Its growth is ground truth:

```bash
F=<agent output/transcript path>
echo "size now:   $(wc -c < "$F")"   # NOT stat -- see below
sleep 20
echo "size after: $(wc -c < "$F")"
```

- Size grew → it is alive. Wait.
- Size completely static across two checks several minutes apart → **it is
  probably wedged.** Kill it and change approach.

**Measure with `wc -c`, not `stat`, and do not trust mtime at all.** Two
independent traps, both of which will tell you a healthy agent is dead:

- The path you are given may be a **symlink** to the real transcript. `stat`
  then reports the *symlink's* own size (a constant — the length of the target
  path) and the symlink's creation time, which never changes however much the
  agent writes. `wc -c` follows the link; `stat` does not.
- Even on a real file, a buffered writer can leave mtime looking many minutes
  stale while the contents grow steadily.

So: `wc -c`, twice, and compare. If the two numbers differ, it is alive —
full stop. Treat any size that looks suspiciously round, tiny, or identical
across very different agents as a sign you are measuring the wrong thing
rather than as evidence about the agent.

Do NOT read that transcript's *contents* — it is the agent's full JSONL log
and will blow out your context. Size only.

### Rules for the wait itself

- **Never write a bare poll loop.** `sleep N` + re-check-status + "still
  running, holding" repeated is a tight loop with the model in it. It produces
  nothing and costs a turn every iteration.
- **Prefer being woken.** Background agents notify on completion. Idling by
  hand is almost always unnecessary — the notification is coming.
- **If you must wait, wait on a condition, not a clock.** Block on the thing
  itself (`while kill -0 $PID 2>/dev/null; do sleep 5; done`) rather than
  sleeping a fixed interval and re-asking.
- **Set a liveness budget up front.** Decide before spawning: "if the
  transcript hasn't grown in 5 minutes, it's dead." Then honour it. Without a
  budget there is no moment at which you decide to stop waiting.
- **If you catch yourself emitting the same status line twice, stop.** That is
  the signal. Go check liveness.

### When it IS wedged

Kill it (`TaskStop` / equivalent) and **change the shape of the work** — do not
respawn the identical task and hope. The usual cause is scope: one agent asked
to review 2500 lines plus surrounding code has to hold too much at once.

## Scope agents so one stall can't block the round

Split a large review into several agents with **disjoint, explicitly listed
file sets**, run in parallel:

- A stall costs you one slice, not the round.
- Each holds less context, so stalls get rarer.
- Disjoint scopes mean no duplicated work and no merge conflicts in findings.

Split along natural seams — one agent per subsystem, plus a dedicated
tests-and-docs-and-claims agent (see below). Give each the *function names* it
owns, not just filenames, and tell it to read those functions in full in the
working tree rather than only the diff hunks: the worst bugs live in the
interaction between changed code and untouched callers.

While they run, review something **they are not covering**. There is almost
always a file left out of every slice. That is free parallelism and it is where
you will find the bugs nobody was assigned.

## Write down what you already considered — before the round lands

Keep a running `known.md`: fixes already made, and things considered and
deliberately rejected *with the reason*. Write it **before** the review returns,
so "I already knew that" can't be constructed after the fact.

Without it you cannot tell a genuinely new finding from a restatement, and the
loop has no stopping condition. With it, the fixed point is well-defined:

> **Stop when a fresh round surfaces nothing that isn't already in `known.md`.**

A finding that merely restates a rejected item is not new — but *do* re-read
your stated reason. If the reviewer's argument is better than your rejection,
the item was never actually settled.

## What to tell each reviewer

- **Don't leak your conclusions.** No "I already fixed X" and no list of known
  issues. That is the whole point of a fresh reviewer; priming it destroys the
  independence you are paying for.
- **Demand a concrete failure scenario** per finding — inputs/state → wrong
  output. This is the cheapest filter against plausible-sounding fiction.
- **Require a confidence label** (confirmed / unconfirmed) and say explicitly
  that finding nothing is an acceptable result. Otherwise you get padding.
- **Make it read, not pattern-match.** "Verify by tracing the real code path;
  do not report something because it resembles a common bug class."
- **Point it at claims, not just code.** Comments, docstrings, commit messages
  and docs make confident assertions about library internals and about what the
  code does. On multi-iteration work these rot first — an earlier round's
  comment describes an earlier round's design. A confidently-worded claim that
  is now false is a real finding.
- **Say READ-ONLY** and mean it: no edits, no commits. If it wants to test a
  hypothesis by breaking something, tell it to copy to a scratch dir.
- **Give it the test command**, including whatever flags the suite needs to not
  silently skip (salt, for instance, skips everything without `--core-tests`),
  and name the known-failing tests so it doesn't rediscover them as findings.

## Ask for mutation testing — it is the difference between "tests pass" and "tests test"

The single highest-value instruction you can give a reviewer looking at tests:
**break the code on purpose and check whether the suite notices.** Have it copy
the repo to a scratch dir, invert a condition or delete a line, and re-run.

A suite that stays green after the feature is disabled is not covering the
feature. This finds things that reading tests never will, and it comes back as
evidence rather than opinion — "hardcoding this to `True` leaves all 149 tests
passing" is not a matter of taste. In one round this turned up a flag whose
removal killed the feature outright with a fully green suite, and three
separate "tested" behaviours whose tests were satisfied by something other
than the behaviour in their name.

Then turn it on yourself. **Before believing a test you just wrote, mutate the
fix it covers and confirm the test fails.** Writing the test after the fix
means you never saw it fail, and a test that cannot fail is worse than none —
it reports coverage you do not have. Expect roughly one in four of your own
new tests to survive the mutation and need strengthening.

Watch especially for tests of environment- or time-dependent bugs. A test for
"this breaks in the first five minutes of host uptime" passes trivially on a
host that has been up for days; it has to pin the clock to mean anything. If a
test would pass on the broken code *in your environment*, it is not a test.

## Triaging what comes back

Sort each finding into: **real and new** → fix; **real but already considered**
→ check the reviewer's reasoning against your recorded one, then move on;
**wrong** → say why, in a sentence, and move on.

Do not treat a subagent's report as authoritative. Reviewers hallucinate
mechanisms and misread control flow with total confidence. Verify before you
act — especially for anything you are about to describe in a commit message as
a fix.

**Verify the proposed remedy separately from the finding.** A reviewer can be
exactly right that something is broken and still hand you a fix that is wrong,
and the correct diagnosis makes the bad remedy persuasive. One round produced a
genuine "this read can silently return a partial answer" finding alongside a
one-line fix that would have permanently disabled the feature on any cluster
that grew a member, because the list it counted may contain duplicates and the
caller's own identity. Treat the finding and the fix as two claims needing two
verifications.

**Look for the reformulation before fixing findings one at a time.** Several
findings often share a root, and patching each one separately buys guards that
interact badly. Three separate findings here — a clock-skew hang, a record that
ages into a wrong answer, and a misleading freshness rule — all dissolved by
comparing two timestamps written by the *same* clock instead of against the
reader's. One change, better than the three guards it replaced. Ask "what
single wrong assumption produces all of these?" before reaching for the first
fix.

**When reviewers contradict each other about a library's behaviour, read
the library.** Two agents asserting opposite things about the same function
are not two opinions to weigh — neither assertion is evidence, and picking
the more confident one is a coin flip. Black-box testing often cannot
settle it either: the path may not be reachable from a normal client.
Fetching the dependency's source at the exact installed version and reading
the function takes a few minutes and ends the argument. In one loop this
overturned the *majority* view — two rounds had "verified" a claim the third
called false, and the source showed the two were right, with an upstream
`TODO` sitting on the very line in question. The same read also explained a
behaviour I had measured but not understood. Pin the version, quote the
code in the comment, and the claim stops being re-litigated every round.

**Treat independent confirmation as a priority signal.** When agents with
disjoint scopes reach the same defect by different routes — one tracing control
flow, one measuring behaviour, one checking a docstring's claim against the
code — that is as close to certainty as this process gets. Fix those first.

Expect to find bugs **in your own previous round's fixes**. That is normal and
is most of the loop's value. When you do, fix them in the commit that
introduced them rather than stacking a follow-up, so each commit still stands
on its own (see the `git-rebase-interactive` skill — and note that amending
mid-rebase has its own silent trap).

**Do the history rewrite once, after the loop converges — not every round.**
Keep fixes accumulating while the loop runs and record as you go which commit
each one belongs to. Splitting after every round means repeating a delicate
rebase on a tree the next round is about to change again: the same risk paid
several times for a tidiness nobody sees until the end. The requirement is
that the *final* history is clean, not that it is clean at every intermediate
step. This also keeps each round's reviewers looking at one coherent tree
rather than a half-restructured one.

**Accumulate them in a `wip` commit, not in a dirty working tree.** The two
are equivalent for everything the loop needs — putative changes, a deferred
message, an undecided amend target — but uncommitted work is the only form
that can be *irrecoverably destroyed*, and this workflow points several
agents at one checkout. A stray `git checkout -- <file>`, `git stash`, or
`git clean` from a reviewer tidying up after itself silently reverts work
that exists nowhere else. Commit it as `wip` and that stops being possible:
the content is in the object store and reachable from the reflog, so the
worst case is a `git reset`, not a retype.

Three things get easier at the same time:

- **Reviewers get a stable diff.** `git diff origin/master..HEAD` includes
  the fixes, so you no longer have to warn every agent that the real change
  set is `git diff origin/master` and that `..HEAD` is a lie.
- **Restore becomes safe again.** A mutation-testing agent can put a file
  back with `git checkout -- <file>` — the normal, obvious thing — instead of
  needing a byte-exact snapshot and a hash manifest, and instead of needing a
  rule it might forget.
- **The diff stays legible.** `git diff` shows only what you are editing
  right now, not the accumulated work of five rounds.

Amend the `wip` commit as the rounds go (`git commit --amend --no-edit`), or
stack `wip 2`, `wip 3` if you want per-round boundaries to look back at. At
the end it is absorbed into the real commits by the same rewrite you were
going to do anyway, so it costs nothing.

Three caveats. Reviewers reading commit messages need something to read, so
hold message corrections in your notes and apply them with the split. Keep
the mapping written down the moment you make each fix — reconstructing
"which commit introduced this?" for thirty changes at the end is far harder
than noting it once.

And **reconcile the changed-file list before you rewrite anything.** Git
decides a file is unmodified from cached stat info, and will skip comparing
contents when that info still matches — so a file you really did change can
be missing from `git status` and `git diff` entirely. Agents copying the
tree, or your own stash/checkout round trips, can leave it in that state.
In one loop this hid six modified files, including a change to an abstract
base class without which the suite would not have passed; it surfaced only
because the file *count* disagreed with memory. Before the split: `touch`
the tree, `git update-index --really-refresh`, then check the list against
what you believe you touched. A count you cannot explain is the signal.

The same check catches a different failure with the same symptom: a file
that dropped off the list because an **agent reverted your work**. In one
round a mutation-testing agent restored a file from a backup it had taken
before my fixes existed, so two of them vanished and the file's blob hash
matched `HEAD` exactly — git was telling the truth, the content really was
unmodified. Only "I edited that file twenty minutes ago, why is it not
listed?" caught it. Then verify each fix is actually present by grepping for
it, not by remembering that you applied it. (Working from a `wip` commit
makes this far less likely in the first place — see above.)

## Terminating

The loop ends when a fresh round produces only already-considered items. Say so
explicitly, and report what you deliberately did not fix and why — a
deliberately-accepted issue is a result, not an omission.

Guard against two failure modes at the end:

- **False convergence** — rounds come back empty because the prompts got narrow
  or the reviewers got primed, not because the code is clean. If a round finds
  nothing, confirm the reviewer actually covered the scope before you call it
  converged.
- **Endless polish** — late rounds returning only style preferences means you
  hit the fixed point a round ago. Stop.

## Verify the tree with blob hashes, not `git status`

`git status` can lie, and the usual fix is not always enough. In a **linked
worktree** with `core.fsmonitor=true`, plain `git status` under-reported 15
of 28 modified files, and `git diff --quiet HEAD -- <file>` claimed a file
was identical to HEAD while the blob hashes differed. `git update-index
--really-refresh` did **not** clear it — fsmonitor short-circuits the
refresh.

Reliable forms:

```bash
git -c core.fsmonitor=false status --short     # bypass the daemon
git rev-parse HEAD:<path>                      # ground truth
git hash-object <path>                         # ground truth
```

Use the bypass flag on **every** git command during a commit split, or files
will be silently omitted from commits.

The trigger for checking was a mismatch between the file count and memory:
"I edited crypt.py, why isn't it listed?" Keep a running expectation of which
files you have touched and reconcile it against what git claims. A reviewer
agent reporting "I restored everything to my backups" is also worth checking
— its baseline predates your edits.

## Never format a whole tree

Running a formatter over a directory (`black salt/`) rather than over the
files you edited can silently damage unrelated code. In one case it
reformatted `#%%OPTS` to `# %%OPTS` — a *substitution sentinel* matched
literally elsewhere (`SSH_PY_SHIM.replace("#%%OPTS", arg_str)`), which would
have broken an entire subsystem with no test covering it.

Before finishing, audit scope:

```bash
git -c core.fsmonitor=false diff --name-only <base> | sort
```

and diff that against the files the work is *supposed* to touch. Anything
unexpected is either a formatter artifact or a reviewer's unrestored
mutation. Both are real.

## Don't edit the tree while reviewers are running in it

The mirror of the rule below, and the more expensive one. Reviewers build and
run in the same checkout you are editing, so a round you start and then
immediately begin fixing produces three distinct failures:

- **Your test runs race their builds.** A reviewer relinking the binary while
  your suite spawns it yields errors that look like real defects and are not —
  `spawn ... EACCES` on a binary that is simply mid-write.
- **Their results describe a tree that no longer exists.** Mutation findings
  against code you have since rewritten are not merely stale, they are
  misleading, because the mutation table still reads as evidence.
- **Stopping one mid-flight can leave a mutation behind.** An agent killed
  between "apply mutation" and "restore" leaves the mutation in your tree. In
  one round that was `return true;` substituted into the predicate that gated
  the entire feature under review — it would have been committed had the
  changed-file list not been grepped for the marker.

So: finish editing, *then* launch the round, and treat the tree as read-only
until every agent reports. If a fix genuinely cannot wait, stop the agents
first and relaunch them afterwards; a round you have invalidated is cheaper to
rerun than to interpret.

When agents do mutate, require of them:

- **Absolute paths in every script.** A relative `cd test/cts` followed by
  `cd ..` lands in the wrong directory, and the restore silently fails while
  the script reports success.
- **A distinctive marker in every mutation**, grepped for after each restore
  and once at the end. `grep -rn MUTMARK` is the cheapest insurance in this
  whole workflow.
- **No `pkill -f "<pattern>"`.** It matches the invoking shell's own command
  line and kills the session running it, usually leaving no output to explain
  the disappearance. Resolve PIDs first (`pgrep -f "[c]r_proxy ..."`), then
  kill by PID.

## Don't run tests over a scope a reviewer is still mutating

A full-suite run reported two failures; a rerun reported two *different*
ones. An in-flight reviewer was mutating that file to verify coverage.
Results over that scope are meaningless until it finishes — and reporting
them as regressions is worse than not running them. Partition test runs by
reviewer scope, and only run a scope whose reviewer has reported.
