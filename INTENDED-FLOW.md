# The intended flow

One path, written down once, so that changes can be checked against it instead of against
whoever last remembered it. Every patch in this tool's history has defended a path that
existed only in conversation — which is why the same failure has been fixed three times and
come back three times.

This file is the contract. Four suites hold the tool to it — `agent-questions.sh`,
`agent-next-action.sh` and `agent-transitions.sh` for the conducted path, and
`no-bare-commands.sh` for the handover it replaced. When the intended path genuinely
changes, this file changes *first* and those suites change with it; a change that
contradicts this file without editing it is a regression by definition, no matter how
reasonable it looked in isolation.

## The shape, in one sentence

**The agent conducts the wizard inside the conversation.** It is not a router that hands the
developer a command, and it is not an author that invents its own version of the wizard's
questions. Every screen the terminal can show, the chat can show; the tool supplies the
words, the developer supplies the answers, the agent carries them in both directions.

## The waypoints

Numbered because the auditor reports divergence by waypoint.

**W1 — Scope.** First prompt, the agent establishes what the developer wants integrated and
confirms it. *Verified working; do not redesign it.*

**W2 — The Android work.** The agent writes config, init and identity, guided by the skill
and `PITFALLS.md`. It never fakes an input to make a build pass: no placeholder
`google-services.json`, no invented API key, no commenting out the `google-services` plugin.

**W3 — The discovery.** The agent finds that some combination of these is missing: a real
`google-services.json`, the Firebase app registration, the Iterable API keys, the push
integration. **This is the divergence point.** Every observed failure of this tool has
happened here and nowhere else.

**W4 — The offer.** The agent puts the Google/Iterable half to the developer as a question
it asks *in the conversation*: here is what is missing, here is the tool that can do it,
here is what it will read and change, may I run it? Running it in their terminal is **one of
the options that question offers**, not the recommendation and not the default. The words
come from the tool (`agent question opening`), not from the agent.

**W5 — The consent.** The developer answers. Only the developer's answer is consent. Not a
signed-in `gcloud`, not an obvious next step, not a previous yes to something adjacent, not
the agent's own reading of what they'd probably want.

**W6 — The conduct.** On yes, the agent drives the scripts and relays each screen: it asks
the tool for the next question, shows the options to the developer, takes their choice, and
feeds it back to the tool. Project selection is the canonical example — the tool ranks and
words the options, the developer picks one, the agent records the pick. The agent never
composes a menu, never picks on the developer's behalf, and never reports a step as done
that it has not run.

**W7 — The proof.** A real push lands on a real device, verified by something that did not
perform the step it is verifying. The tool never grades its own work.

## What divergence looks like

The three classes, because they need different fixes and get confused constantly:

- **Class A — the text tells it to do the wrong thing.** Prose that says to relay a command
  and stop, or to hand over. Fix: edit the text.
- **Class B — the text says the right thing and nothing enforces it.** A rule that lives
  only in a sentence. Fix: put the check in the program. Consent is a mechanism, not a
  paragraph.
- **Class C — the right action exists and is more expensive than a wrong one.** The
  intended path costs more turns, more reading, or more guessing than the shortcut, so a
  model under pressure to be useful takes the shortcut. **This is the class that keeps
  regressing**, because every individual patch looks correct and the cheapest path is
  unchanged. Fix: make the intended action the cheapest one available.

A fourth thing that is *not* divergence: a not-yet state. A gate that is pending because a
human has not acted is the tool working, and reporting it as a defect is its own bug.

## Where each waypoint is pinned

A waypoint defended only by this file is defended by nothing. What holds each one:

- **W4, the offer** — `tests/agent-next-action.sh`: every ladder state routes to one owner
  and one kind, and the fork is reported while it is unanswered rather than one of its
  answers.
- **W5, the consent** — `tests/approval-gate.sh`: a yes needs the token the screen carried,
  and has to arrive slowly enough to have been read. `tests/agent-questions.sh`: the screens
  say what the terminal says.
- **W6, the conduct** — `tests/agent-transitions.sh`: the walk takes each screen's own
  recommended answer, runs what it carries, and asks again. A state that comes back
  unchanged fails. This is the one that was missing, and its absence is the whole reason
  the same failure returned three times: **the other suites pin states, and the defect
  lived in the transition between them.**
- **Every routed state names something to run** — `expect()` in
  `tests/agent-next-action.sh` fails an empty `next.command`. The exceptions are the steps
  no script of ours performs: install a toolchain, build, run the app, look, send a
  campaign. A state whose remedy cannot be named ends in a handoff, every time.
- **Delivery** — `tests/plugin-manifests.sh`: if anything a client receives differs from
  `main`, the manifest version has to differ too. A fix that does not reach the installed
  copy is indistinguishable from no fix, and that is how a season of them was spent.

## Standing constraints the flow may never trade away

- The developer's Google and Iterable passwords are never handled by the tool; they
  authenticate in their own browser or `gcloud` and the agent attaches to that session.
- Never ask anyone to paste a secret into the conversation. Keys move by file path, env
  var, or `iterable-keys --take`; the agent never reads the clipboard itself.
- `APPROVED=1` is the CI form of consent, for a run with no human in it. The agent never
  sets it.
- Three yeses, three sizes, none implying the next: `list` to look at the estate,
  `firebase` to change a project, `create-app` to add an app.
