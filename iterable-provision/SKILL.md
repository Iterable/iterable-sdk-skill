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

## The loop

Run it **from the developer's project directory**, by absolute path:

```
<root>/bin/agent
```

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

| `next.kind` | What you do |
|---|---|
| `install_tools` | Report exactly which binaries are missing (`missing_tools`) and what each unlocks: `gcloud` the Google half, `adb` the device half, `node` the JSON parsing, `java` the keystore reads. Do not install them. |
| `authenticate` | Ask the developer to run `gcloud auth login` **themselves**, in their own terminal. You never handle their Google credentials. |
| `choose_target` | Run `<root>/bin/agent discover` for the JSON list of their Firebase projects and Android apps, then ask **one** `AskUserQuestion` listing real projects (a project that already has their package is the zero-mutation path — say so). Record it with `<root>/bin/agent set PID=… PACKAGE=…`. |
| `project_unreachable` | Relay `next.summary` verbatim; it is a permissions answer from Google, not something to work around. |
| `register_app` | Registering an Android app in their Firebase project is a real mutation. Ask outright, and only then re-run with `CREATE_APP=1`. |
| `provision` | Show `next.summary`, get one confirmation, then run `<root>/bin/onboard --apply`. It creates the service account, binds the send-push role and nothing more, downloads `google-services.json`, and ends by re-running the ladder. |
| `iterable_keys` | Four steps in their Iterable account that only they can do. Walk them **one at a time** — see *The four Iterable steps* below. |
| `install_app` / `run_app` / `send_proof` | The device half — hand off to `iterable-verify`. |
| `done` | A real push reached the device. Say which device and chain onward. |

`next.command` is the command for that step when there is one. Run it; do not
compose your own equivalent.

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

Open by saying what the stretch is: four things in their Iterable account, a couple
of minutes, and nothing downstream works without them. Then, for N in 1 to 4:

1. Run `<root>/bin/iterable-keys --step N` and show its output as it is. It is
   written to be read by the developer — do not summarise it, do not retype the
   URLs, do not merge two steps into one message.
2. Ask **one** `AskUserQuestion`: *Done* / *It doesn't look like that* / *I'd rather
   run the whole thing myself*. Then wait. Step N+1 does not exist until they answer.
3. *It doesn't look like that* — help with that step and no other. The dashboard
   moves; the values and their meanings do not.
4. *I'd rather run the whole thing myself* — give them `<root>/bin/iterable-keys`
   with no arguments, at their own terminal. It prompts with the echo off, stores
   the keys itself, and ends by running the ladder. Stop walking and wait for them.

The two keys go into a file, never into the conversation. Step 1's output names it:
`.iterable/.env.template`, mode 0600, which they fill in and rename to `.env`. **Do
not ask them to paste a key to you**, not even to check its shape. If they paste one
anyway, say plainly that it is in the transcript now and worth rotating — Iterable
keys are cheap to replace — then carry on with the file.

When they say step 4 is done, re-run `<root>/bin/agent`. Both keys get spent on a
real call and the test user is looked up by name, so nothing here rests on anyone's
word. A key that works for one endpoint and not the other means the two are
swapped — a common mistake, and the check tells them apart.

## Secrets

`<root>/bin/iterable-keys --step N` prints one dashboard step and, the first time,
writes `.iterable/.env.template` at mode 0600 with three empty names. Without
arguments and without a terminal it prints all four at once — that is the form for a
script, not for a conversation.

- **Never ask anyone to paste a key into the conversation.** Not as a question, not
  as an `AskUserQuestion` option, not "just to check the format".
- Never read `.env`, echo it, `cat` it, or pass a key as a command-line argument.
- You do not need to see a key to know it works. The check spends both keys on real
  calls — including a deliberately invalid control key, so a probe that cannot tell
  a good key from a bad one goes red rather than green.
- The service-account key at `.iterable/artifacts/sa-key.json` is a long-lived
  credential. Its path is the only thing you ever mention about it. The developer
  uploads that file to Iterable themselves; `<root>/bin/wizard` offers to delete it
  afterwards, and `<root>/bin/teardown` removes it from Google.

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
