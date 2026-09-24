---
name: iterable-provision
description: >-
  Produces and proves the prerequisites for Iterable push on Android — a Firebase
  Android app and its `google-services.json`, a service account scoped to sending
  push plus its key, and the four Iterable dashboard steps (two API keys, the mobile
  app, the Firebase push integration with FCM type Data notifications, the test
  identity). Use when the developer does not yet have a `google-services.json`, an
  Iterable mobile API key, or a configured push integration — including phrasings
  like "set up FCM for Iterable", "create the push integration", "I don't have the
  Firebase config", or when the `iterable-android` / `iterable-react-native` skill
  reaches a Preflight input nobody has. Never fabricate these inputs; get them here.
---

# Provisioning Iterable push, and proving it

This skill drives a program. You are not the state machine — `<root>/bin/agent` is. It
reads the world, decides the single next action, and tells you who owns it. Your
job is to run it, do what `next` says, and run it again.

**You never grade your own work.** The scripts that change things and the ladder
that checks them are separate programs on purpose: a front end that both acts and
reports its own success is exactly the false green this tool exists to prevent.
When you have done something, re-run `<root>/bin/agent` and believe its answer, not your
recollection of what you just did.

## Finding the scripts

Hosts copy a plugin into a cache on install and set no environment variable, so no
path here is stable. Start in the directory containing this `SKILL.md` and walk up
until you reach the first directory containing a `bin/agent`. Call that `<root>`.

If you reach the filesystem root without finding it, the install is
incomplete. Say so and stop. Do not guess at a path, and do not reimplement any of
these checks by hand.

## Before you run anything

The first command is not the ladder. It is the question that asks whether to start one:

```
<root>/bin/agent question opening
```

**Ask it, and wait for an answer, before you run any other command here.** It spends no
credentials, reads nothing, and writes nothing — not even a workspace directory — so it
is safe to be the first thing that happens. Render it exactly as *When the tool hands you
a question* says: `context` above the selector, verbatim, then the options.

This ordering is the point and it is easy to get wrong. A status read runs the whole
eighteen-gate ladder against their Firebase projects, so a question carried in its output
arrives *after* the work it was asking about. Twice now an agent decided provisioning was
needed, ran it, and presented a project picker — and a project picker is not a consent
screen. **Deciding that setup is needed is not permission to start it.** Announcing what
you are about to do is not either.

If they say no, stop. Do not run the ladder "just to see where things stand".

## The loop

Once they have said yes, run it **from the developer's project directory**, by absolute
path:

```
<root>/bin/agent
```

You keep using `<root>/…` for everything you run yourself: it is absolute, so it does
not care what directory you are in. **The developer does not.** Every entry point they
are ever told to run also exists as a short stub in their workspace — `.iterable/onboard`
and friends — because the real path is a version-numbered cache directory that is
untypeable, and that hosts keep old copies of, so a path they save today silently runs
old code after the next update. The stubs are rewritten on every run.

So when you relay a block from the tool, **relay it verbatim.** Do not substitute the
long path you happen to be using: the block already names the form that works for them.

**Never `cd` into `<root>` first.** The workspace is resolved from the working
directory — it belongs in the developer's repo as `.iterable/`, because the plugin
cache may be read-only and is erased on the next update. The tool refuses with exit
`30` rather than write there, so a wrong `cd` is loud instead of silently losing
their state. Every command in this skill follows the same rule: absolute path to the
script, run from their project.

One JSON object on stdout; the human-readable ladder goes to stderr (read it when a
verdict surprises you — it is the account of what happened). Exit code mirrors
`verdict`: `0` done, `10` blocked on a human, `20` a real defect, `40` nothing
broken and nothing proven yet.

Read `next.kind` and act. That is the whole protocol.

## When the tool hands you a question

A few steps are the developer's *decision* rather than their work. On those,
`next.question` is an object instead of `null`, and its presence is the whole
instruction: **ask it, do not answer it.** Later steps of a walk come one at a time:

```
<root>/bin/agent question iterable_step 2
```

Render it as one `AskUserQuestion`:

- `context` goes in the message **immediately above** the selector, every line, verbatim.
  That is what they are agreeing to. The wording is the tool's because a shortened
  version of it still comes back "yes".
- `requires`, when it is not empty, goes in the same message. It is what they have to do
  themselves, in their own terminal.
- `header` is the chip, `prompt` is the question, and each entry in `options` is one
  option — `label` as the label, `description` as the description.
- When they pick one, run that option's `commands` in order, then read the ladder again.
- An option with a non-empty `relay` has **no** commands for you. That is a command only
  the developer can run — it hosts a sign-in, or takes a key with the echo off. Print it,
  say you will wait, and stop. Running it yourself puts the thing it was written to
  protect into whatever is reading your output.
- `free_text`, when present, is the answer that is not on the menu — a project the picker
  had no room for, a package only they know. The host adds that entry for you (it is
  *Other*); `hint` is what to ask for. When they type something, put it where `{{answer}}`
  is in `command` and run that. `bin/agent set` checks the format and exits `30` with an
  `error` that is written for the developer — relay it and ask again rather than correcting
  their value for them. **Never** for a secret: no API key, no password, no token — those
  have their own screens and their own relays.
- `recommended`, when it is not null, is the option the tool would pick. It is a label to
  pass on, not a decision that has been made: `null` means the tool has no view, which is
  most of the pickers, because which of somebody's projects is theirs is not ours to rank
  on anything but what creates the least.

**Do not add, drop, reword or reorder the options, and do not pick one yourself** — not
even when only one of them looks sensible from where you are sitting. An option nobody
was shown was never declined. `effect` says what each one changes; it is there so you
can tell them, not so you can choose.

The answer has to land on disk, which is why the yes is a command and not a note in this
conversation: `may_drive_setup` reads the file, so an approval that only ever existed in
a transcript stops the run just as a missing one does.

`question: null` means the next step is work rather than a choice. Get on with it.

There are **three** of these before anything in their Google project changes, and they
are not the same ask. In order: `opening`, before you run a single command — is this job
happening at all. Then `choose_target`, before you list anything — reading their projects
is the first thing that spends their Google credentials, and agreeing to it is not
agreeing to changes. Then `approve_firebase`, before the first change, once a project is
chosen and there is a real list of changes to show.

**None of them covers the next one, and none is optional because a later one is coming.**
A developer who would have stopped at the first has, by the third, had their whole
Firebase estate read out and printed into this conversation.

A fourth, only when their project has no Android app for this package: `register_app`.
That one *creates* something in their project, which the stated limits promise never
happens unless they ask outright — so the provisioning yes does not include it, and its
own yes is recorded under its own scope and against that one project.

## Who runs the Google setup — theirs to choose, and unanswered until they do

**Conduct it here unless they ask for the terminal.** Every screen the wizard shows has a
twin in `next.question` — registering a missing Android app, picking the device by name,
taking the API keys — so the chat is the whole walk and not a cut-down version of it. The
terminal is the fallback, for somebody who would rather not answer these here at all.

One thing that path does that a conversation cannot: it hosts `gcloud auth login` in the
same session instead of relaying it. That is the reason to keep it, and it is the whole
list.

While nobody has answered, `next.kind` is **`choose_driver`** — the fork itself, with
`next.command` being `agent question opening`. Ask it. Do not relay a terminal block here:
that is one of the two answers, and presenting it as the next step answers for them.
`setup.chosen` is `false` until somebody has actually said, and `setup.recommended` reads
`agent` until then rather than guessing from `setup.driver`, which sits on its fallback.

**Only they can make that choice.** Setting `DRIVER=agent` because handing over felt slow
takes a decision that is theirs; relaying the handoff because the chat felt like work does
the same thing in the other direction.

Once they have chosen the chat, `setup.handoff_command` is `null` and `<root>/bin/handoff`
prints where the run has got to and what the next part needs — not the terminal block. So
there is nothing left to reach for there, and nothing to relay that contradicts what they
answered. None of these boxes tells anybody to run a command, and they are not meant to:
you were handed the next step in the same read. What the box is for is the developer
knowing the run reached this point and what they are being asked to let you do next.

Once they have chosen the terminal, `next.kind` is `run_in_terminal`:

1. Run `next.command` (`<root>/bin/handoff`) and relay its block **verbatim**. It
   contains the two lines they type, what the wizard will ask them, and how to come
   back. Do not retype the command and do not drop the last part.
2. Say plainly that you will wait, and **stop**. Do not run provisioning commands
   while they are in the terminal, and do not start writing integration code that
   depends on what the wizard is about to produce.
3. When they come back — whether it worked or not — run `<root>/bin/agent` again and
   read the result off disk. **Never ask them to paste or retype anything**; the
   workspace is in their repo and it is the authority on what happened.

The question carries every answer, so you do not write them: the one it names in
`recommended` is the tool's pick, and the option that records `DRIVER=agent` is what
unlocks *Once they hand it to you* below.

The scripts hold the same line, so this is not on your memory: `bin/provision` and
`bin/onboard --apply` refuse with exit `10` and print the handoff block when nothing
on disk records that request. **If you see that refusal, you skipped the handover** —
relay the block, do not look for a flag that gets you past it, and never set
`APPROVED=1` (the CI form, for a job with no human in it) to make it go away.

## Every state, and the one thing it asks of you

| `next.kind` | What you do |
|---|---|
| `choose_driver` | Nobody has said who runs the Google half yet. Ask `next.question` (`agent question opening`) and wait for their pick. **Do not relay a terminal block here** — that is one of the two answers. |
| `run_in_terminal` | They chose their own terminal. Relay the handoff block verbatim, say you'll wait, stop. |
| `install_tools` | Report exactly which binaries are missing (`missing_tools`) and what each unlocks: `gcloud` the Google half, `adb` the device half, `node` the JSON parsing, `java` the keystore reads. Do not install them. |
| `authenticate` | Ask `next.question`; its first option carries `gcloud auth login` as a `relay`. They run it themselves, in their own terminal. You never handle their Google credentials. |
| `choose_target` | **Ask `next.question` before you run anything.** Listing their projects is the first thing here that spends their Google credentials, and it prints their whole Firebase estate into this conversation. A signed-in `gcloud` is a capability, not a permission — so `discover` refuses with exit `10` until the yes is recorded, and its first option is what records it. Once they agree, run both commands that option carries — then ask the *same kind again*. With a listing on disk it comes back as the picker: their real projects, the one that already has their package ranked first because it is the path that creates nothing, and a free-text option for the rest. **Do not write that menu yourself.** With a project already chosen the same kind asks which app instead. |
| `project_unreachable` | Relay `next.summary` verbatim — it is a permissions answer from Google, not something to work around — and then ask `next.question`, which offers aiming somewhere else. A typo'd project id and a project they have no access to look identical from here, and both are answered at that screen. |
| `register_app` | Their project has no Android app for this package. Ask `next.question` — this is the one change the limits promise never happens unless they ask outright, so its yes is separate from the provisioning yes and recorded with `<root>/bin/agent approve create-app`. Never `CREATE_APP=1`. |
| `iterable_keys` | Four steps in their Iterable account that only they can do. Ask `next.question`, then walk them **one at a time** — see *The four Iterable steps* below. The two keys reach the workspace with `iterable-keys --take server\|mobile`, off their clipboard; never into this conversation. |
| `install_app` / `run_app` | The device half — hand off to `iterable-verify`. Until a device is on record `next.question` is the device picker, worth asking even when only one is attached: a phone left plugged in to charge is "the only device", takes the proof push, and the developer watching an emulator reports that nothing arrived. After that, `run_app` keeps a question of its own — signing in and allowing notifications happen inside their app, by their hand. Relay it. Never drive their device over adb. |
| `send_proof` | The device half — hand off to `iterable-verify`. |
| `done` | A real push reached the device. Say which device and chain onward. |

`next.command` is the command for that step when there is one. Run it; do not
compose your own equivalent.

### Once they hand it to you

You reach these three only after `bin/agent set DRIVER=agent`. Until then `next`
never names them, and the scripts behind them refuse. Reading a command out of this
table and running it anyway is the one shortcut this skill exists to prevent.

| `next.kind` | What you do |
|---|---|
| `approve_firebase` | Nothing has touched their project yet, and nothing will until they say yes. See *Asking before you change their project*. |
| `register_app` | Their Firebase project has no Android app, so there is no `google-services.json` to download and nothing downstream can work. Ask `next.question`; a yes runs `<root>/bin/agent approve create-app`, which is scoped to that one project. **Never `CREATE_APP=1`** — that is the environment's flag, for a pipeline with no human in it, and setting it yourself is you answering the one question the stated limits promise is theirs. **This is the state that must never turn into a workaround** — if the answer is no, hand it back rather than writing code around the missing file. |
| `provision` | Show `next.summary`, then run `<root>/bin/onboard --apply`. It enables Firebase on the project, registers the Android app if that yes is on record, creates the service account, binds the send-push role and nothing more, downloads `google-services.json`, and ends by re-running the ladder. Their yes is already recorded by this point — do not ask twice. **This is also where `register_app` goes once they have said yes to it**: the same state comes back as `provision`, because registering the app is this script's job and no question's. If you are being asked `register_app` again after a yes, something is wrong — report it rather than re-asking. |

## Asking before you change their project

The Google half runs against a cloud project somebody else owns and pays for. So the
list of changes comes before the changes, once, in their words — and their answer is
recorded rather than remembered.

When `next.kind` is `approve_firebase`:

1. Show `approval.plan` from the JSON as a list, verbatim. It is generated from the
   ladder, so it names what is actually left to do and nothing that is already done.
   Do not summarise it to "set up Firebase" and do not add items to it.
2. Say what it will not do: touch an app, integration or credential they already
   have; create a Firebase project or register an app unless they ask outright; ask
   for or type a password. Say that the JSON key it creates is a long-lived
   credential until they delete it, and that `<root>/bin/teardown` removes everything
   it added.
3. Ask **one** `AskUserQuestion` — *Go ahead* / *Not yet, I have questions*. Then
   wait. **No is a complete answer**: if they decline, say what stops (the Google
   half, and the push proof with it) and leave the project alone. Do not re-ask later
   in the run.
4. On yes, run `approval.command` (`<root>/bin/agent approve firebase`) and carry on.

**Never run that command on their behalf**, and never pass `APPROVED=1` yourself —
it is the CI form of the answer, for a job with no human in it. Recording a yes
nobody gave is the worst thing you can do in this skill. You do not need to police
the rest: `<root>/bin/provision` checks the record itself and exits `10` without
making a single call to Google if the yes is missing. The approval covers one
project; choosing a different one puts you back here, correctly.

**The read is asked for too.** Listing their Firebase projects mutates nothing, and that
is exactly why it gets taken for granted: an agent that finds `gcloud` already signed in
treats being *able* to look as being *allowed* to look, and what lands in the transcript
is every project name, id and package the account can see. So `discover` refuses the same
way `provision` does — exit `10`, nothing read — until a yes is recorded, scoped to that
Google account. Three separate yeses, three separate sizes: `list` to look, `firebase` to
change, `create-app` to add. The first option of the `choose_target` question carries the
command that records the first one; **that command is theirs to trigger by choosing it,
never yours to run because the read looked harmless.**

That one is checked rather than trusted, so you do not have to be relied on for it. The
`list` yes only counts if it came off a screen: rendering `choose_target` mints a one-time
token, and `approve list` needs that exact token — the option's command already carries it,
which is why it is run as written and not retyped. Two refusals come back at exit `10`, and
both mean the same thing. *"No screen for this has been put up"* is an approval for a
question that was never asked: put the question to them. *"That yes arrived Nms after the
screen was generated"* is a screen rendered and answered in the same turn, which nobody
could have read: show it, wait for their answer, then record it. A token is spent by one
yes, so a new decision means a new screen. None of this is an obstacle to a developer who
actually says yes; it only costs you anything if you were about to answer for them.

## Blockers, where nobody can scroll past them

Every run ends in one of four states, and the developer needs to know **whose turn it
is** before anything else. `next.owner` says: `human` means them, `tool` means you.
Lead with that in one short line, then the step name (`next.step`), then
`next.summary`, then `next.command` on its own line if there is one. Set it off with
a heading or a quote block — not a fifth bullet in a list of five, which is a list
nobody starts.

Two distinctions worth keeping, because collapsing them is how this tool loses
credibility:

- **A step nobody has reached is not a defect.** `verdict: pending` means the checks
  ran, reached the service, and found the work simply hasn't happened. Say "nothing
  is broken, and no push has arrived yet" — never "failed", never "error".
- **A red step owned by `human` is still their turn, not a broken integration.** "No
  device attached" is not a bug. Reserve the strong words — wrong, broken, failing —
  for `verdict: defect`, where the tool owns it.

When more than one thing is outstanding, name the one next thing prominently and put
the rest in a plain list below it.

**Never end a turn without a next step.** Whenever you stop — blocked, handing over,
or out of things you can do — the last thing you say has three parts, in this order:

1. **Where it stands.** What is proved, and what is not. One or two lines.
2. **The one thing to do**, as something they can act on without deciding anything:
   the command to run, or the dashboard step, or the question you need answered.
3. **"Then come back and tell me"** — say it outright, and say you will pick up from
   the workspace rather than asking them to report details.

"Provisioning is incomplete" on its own is not a next step. Neither is a list of five
things with no order. A developer who reaches the end of your message and has to work
out what to do next has been handed the problem, not the answer.

## Words to use

The gate ids (`G0`–`G17`) are our vocabulary, not the developer's. They are in the
JSON and in the table on stderr because the state file is keyed on them — never put
one in a sentence you say to the developer. `next.step` is the same step in words;
so is `gates[].name`. Use those.

Ours and not theirs either: *gate*, *ladder*, *pending*, *blocked*, *unverifiable*,
*rc 40*. Say the true thing instead — "nothing is broken, and no push has arrived
yet" — and name what you are waiting for.

## The four Iterable steps, one at a time

Iterable's public API cannot create an API key, a mobile app, or a push
integration, so this is the one stretch of the flow the developer does by hand.
Everything they produce gets proved afterwards by a real call, and your job in
between is to keep it to **one step per message**.

`next.kind` is `iterable_keys` and `next.question` opens the stretch: what it is, why
these four cannot be automated, and that the keys never come through this conversation.
Ask it. Then, for each step the chain gives you:

1. Run `<root>/bin/agent question iterable_step N`. Its `context` **is** the step — the
   numbered clicks, the URL, and the one or two arrows that matter — so show every line of
   it above the selector, as it came out. Do not summarise it, do not retype the URLs, do
   not merge two steps into one message. A shortened step is the most expensive mistake in
   this whole setup: "FCM type: Data notifications" condensed to "enable notifications"
   breaks push while every other check still reads as configured.
2. Then wait. Step N+1 does not exist until they answer, and the answer names it. If you
   find yourself writing the instructions for a dashboard screen, you have skipped the
   `context` — nothing here needs you to compose a step, and a composed one has already
   told a developer to rename a file this tool stopped writing.
3. Its options arrive with the commands that enact them, so the walk cannot lose its
   place or skip a screen. On step 1 two of them are `--take server` and `--take mobile`:
   one click each, and the key goes from their clipboard into the file.
4. One option on every step carries a `relay`, not a `commands`. **Relay it and stop.**
   That is `iterable-keys` with no arguments at their own terminal, the fallback for
   somebody who would rather not do this here — it prompts with the echo off, which is
   the one thing a chat cannot offer.

**The key goes from their clipboard into a file, and you never hold it.** The dashboard's
copy button has just put it there, so `--take server` reads it, writes it to
`.iterable/.env` at mode 0600, clears the clipboard and prints a tick. **Do not read the
clipboard yourself** — `pbpaste` and its kin are off limits here, because a key read into
your own output is a key in the transcript. `--take` is the only thing in this flow that
ever holds one. **And do not ask them to paste a key to you**, not even to check its
shape; if they paste one anyway, say plainly that it is in the transcript now and worth
rotating — Iterable keys are cheap to replace — then carry on with the file.

No clipboard on their machine? Then they put the two values on `ITBL_SERVER_KEY` and
`ITBL_MOBILE_KEY` in `.iterable/.env` themselves, or run the terminal walk. Both are
fallbacks; neither is the first thing you offer.

When they say step 4 is done, re-run `<root>/bin/agent`. Both keys get spent on a
real call and the test user is looked up by name, so nothing here rests on anyone's
word. A key that works for one endpoint and not the other means the two are
swapped — a common mistake, and the check tells them apart.

## Secrets

`<root>/bin/iterable-keys --step N` prints one dashboard step and, the first time,
writes `.iterable/.env` at mode 0600 with three empty names — never overwriting a
value, because an Iterable key is shown once. Without arguments and without a terminal
it prints all four at once — that is the form for a script, not for a conversation.
You do not need to call it on the chat path: `agent question iterable_step N` already
carries the same clicks in its `context`, from the same source.

- **Never ask anyone to paste a key into the conversation.** Not as a question, not
  as an `AskUserQuestion` option, not "just to check the format". `--take` exists so
  that the offer is unnecessary.
- Never read `.env`, echo it, `cat` it, read the clipboard, or pass a key as a
  command-line argument.
- You do not need to see a key to know it works. The check spends both keys on real
  calls — including a deliberately invalid control key, so a probe that cannot tell
  a good key from a bad one goes red rather than green.
- The service-account key at `.iterable/artifacts/sa-key.json` is a long-lived
  credential. Its path is the only thing you ever mention about it. The developer
  uploads that file to Iterable themselves; `<root>/bin/wizard` offers to delete it
  afterwards, and `<root>/bin/teardown` removes it from Google.

## The notice, in the tool's words and not yours

The JSON carries a `notice` field. Relay it **verbatim**, as a quote, at two moments:
once before the first change lands in their repository or their project, and once
when `next.kind` is `done`. Twice in a run, not on every turn.

Do not paraphrase it, do not shorten it, and above all do not soften it into "I've
double-checked everything" — you are the thing it is warning them about, and an agent
vouching for its own output is worth nothing. It draws the line they need: the push
proof is evidence, read back out of the operating system; everything else is a draft
to review like a pull request from somebody new to their codebase.

If they ask whether the setup is trustworthy, the honest answer is the same
distinction — what was proved by a real call, and what was written and not yet
reviewed. `gates[].status` tells you which is which.

## What the tool will not do, and neither will you

- Never fabricate a prerequisite. No placeholder `google-services.json`, no invented
  API key, no commenting out the `google-services` plugin to get a build to pass.
  A missing input is a question, never a guess.
- Never create a Firebase project or register an app unless the developer asks for
  it in this conversation.
- Never touch an app, integration, or credential they already have.
- Never say something is working that has not been proved. Two steps — the mobile
  app in Iterable and the push integration — report as *unverifiable*, because
  Iterable's public API has no endpoint that reads them back. Say that plainly: "no
  way to check this from outside the dashboard, so it gets proved when the push
  arrives." Reading a local file to claim a remote step happened is the exact
  failure this tool exists to catch.

## Two things that cost people whole days

Both are human steps, so they are the two most worth saying out loud:

- **FCM type must be `Data notifications`**, not "Notification messages". With the
  wrong one the Firebase SDK swallows the push, Iterable's SDK never sees it, and
  everything looks configured while no push ever arrives.
- **The test identity is a join key.** It has to be the exact address the app passes
  to `setEmail()`. Any other address files the token under one identity and sends the
  proof to another, which reads precisely like a broken integration. If the app has
  already run, `<root>/bin/iterable-keys` reads what it actually registered out of the SDK's
  own request log and offers that — prefer it over anyone's memory.

## Where this goes next

When `next.kind` is `done` for the Google and Iterable halves, announce the
transition in one line and continue into the platform skill — `iterable-android` or
`iterable-react-native` — to write the integration. Do not ask whether to continue.

The platform skill owns copying `.iterable/artifacts/google-services.json` into
the app module (`app/google-services.json` for a standard Android project) and shows
it as part of its one confirmed diff. This skill produces the file; it does not
write into the developer's source tree.

After the integration is written, `iterable-verify` proves it with a real push.
