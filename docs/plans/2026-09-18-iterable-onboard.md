# iterable-onboard — Implementation Plan

**Date:** 2026-09-18
**Goal:** take an Android developer from *nothing* to *a push notification arriving on a
device*, with every step either automated or explicitly handed back to the human, and with
a machine-checkable gate proving each step actually worked.

This is the companion to the `iterable-android` skill. That skill's **Preflight** section
lists the inputs it must STOP and ask for — `google-services.json`, the mobile API key, a
configured push integration. Those inputs are exactly what this tool produces. The skill
writes the code; `iterable-onboard` supplies the prerequisites the skill cannot invent.

---

## Decisions (locked 2026-09-18)

| Decision | Choice |
|---|---|
| Operator | **Customer developer, self-serve** — runs on their own machine, their own Google account, their own Iterable dashboard |
| Repo | **Standalone** — `Iterable/iterable-onboarding`, published like `iterable-admin-cli` |
| Test target | **A real Iterable sandbox project** (the pattern Iterable's own FCM-migration doc recommends) |
| Human handoff | **Block, write the ask, resume later** — `workspace/ASK.md` + distinct exit code |

Consequence of "customer developer, self-serve": **the tool never handles the developer's
Google or Iterable password.** The human authenticates themselves in their own browser; the
tool attaches to that already-authenticated session. This is both the ethical answer and the
only one that survives Google's automation detection.

---

## Global constraints

1. **Deterministic before agentic.** Every step that has a CLI or REST API uses it. A browser
   agent is used *only* where no API exists. Verified: the four Iterable setup steps have no
   API (see Findings), and nothing else needs a browser except one-time consent screens.
2. **The actor is never the verifier.** A step that clicks "Save" does not get to declare
   success. Each gate is a *pure read* performed independently of the action that produced it.
3. **Never fabricate a prerequisite.** Inherited verbatim from the skill's hard rule: no
   placeholder `google-services.json`, no invented API key, no commenting out the
   `google-services` plugin to get a green build. A blocked run is a good run.
4. **Secrets stay local.** The service-account key is a long-lived credential. Mode `0600`,
   gitignored, never echoed to logs, deletion offered once uploaded.
5. **Resumable and idempotent.** `--resume` re-runs only the gates that are not green. Safe to
   invoke from a loop or a cron tick.
6. **Node 20+.** Matches `iterable-admin-cli`.

---

## Findings that shape the design

All verified 2026-09-18 against primary sources.

### Google side is almost entirely automatable

| Step | Verdict |
|---|---|
| Accept Google Cloud ToS (brand-new account) | **Human, once** — browser |
| `gcloud auth login` | **Human, once** — browser consent |
| Create project | Automatable (`gcloud projects create`); service accounts cannot create projects outside an org |
| Enable APIs | Automatable — `serviceusage`, `cloudresourcemanager`, `firebase`, `iam`, in that order |
| Add Firebase to project | Automatable — `firebase projects:addfirebase` / `projects:addFirebase` REST |
| Register Android app | Automatable — `firebase apps:create android --package-name=…` |
| Fetch `google-services.json` | Automatable — `firebase apps:sdkconfig android <appId>`, or REST `GET /v1beta1/projects/-/androidApps/{appId}/config` |
| Create service account | Automatable — `gcloud iam service-accounts create` |
| Grant FCM permission | Automatable — `roles/firebasecloudmessaging.admin` |
| Create JSON key | Automatable **unless** org policy `constraints/iam.disableServiceAccountKeyCreation` — then console-only |
| Validate the key against FCM | Automatable — `messages:send` with `validate_only: true` |

**Exact role — verified.** `roles/firebasecloudmessaging.admin`, display name *Firebase Cloud
Messaging API Admin*, grants `cloudmessaging.messages.create`. Do **not** use
`roles/firebase.admin`: it over-grants a credential that gets handed to a third party.

**FCM needs no billing** — free on the Spark plan. One less human step.

**Do not build on `FIREBASE_TOKEN`.** `firebase login:ci` is officially deprecated and slated
for removal. Use user ADC for the interactive path.

### Iterable side splits cleanly in two

Searched the public Swagger 2.0 spec at `https://api.iterable.com/api-docs` (public, no auth,
133 endpoints).

**No API exists** for: creating a project, creating a mobile app, uploading the FCM
service-account JSON, setting the FCM message type, or **creating API keys**. All of these are
dashboard-only, and re-confirmed against all 131 paths on 2026-09-21. These three steps are the
*entire* reason a human is still in the loop — and, as built, they are clicks rather than
browser automation.

Two pages do the whole job. Both deep links are **confirmed working** (Franco, 2026-09-21) —
`/settings/mobileApps/create` also appeared in our notes for the first one and is wrong, so the
navigation path is kept alongside as the fallback when a link rots.

| Page | URL | Navigation fallback |
|---|---|---|
| Create the mobile app + push integration | `https://app.iterable.com/integrations/mobileApps/create` | Settings > Apps and Websites → Add a new app or website |
| Create the API keys | `https://app.iterable.com/settings/apiKeys` | Settings > API Keys |

**Superseded 2026-09-21 — the human creates the keys.** This paragraph originally argued that
the browser tier should create both keys to drop the human-touch floor from 3 to 2. See
*The Iterable half is hand-driven* below: the human clicks all three dashboard steps and the
tool proves each result by API. The floor is 3, and that is the honest number.

Two details that matter when creating keys:
- A **JWT-enabled** mobile key shows its shared secret **once**, at creation. If JWT is chosen,
  capture the secret then or it is unrecoverable. Default to a non-JWT mobile key for the
  sandbox verification loop — it is the shortest working path — and state plainly that
  production integrations should consider JWT, which the skill treats as mandatory-if-enabled.
- Key values land in `workspace/.env` at mode `0600`, never in a log or a run report.

**Everything needed to verify is an API**, which means the whole proof loop is scriptable:

| Goal | Endpoint |
|---|---|
| Register a device token | `POST /api/users/registerDeviceToken` (mobile key) |
| Inspect `devices[]` | `GET /api/users/getByEmail` (server key) |
| **Send a test push with no campaign** | `POST /api/templates/push/proof` |
| Create a push template | `POST /api/templates/push/upsert` (`clientTemplateId` required) |
| Confirm send/skip/bounce | `GET /api/events/{email}` — look for `pushSend`, not `pushSendSkip`/`pushBounce` |

`POST /api/templates/push/proof` is the unlock: it sends to a user without a campaign or a
list, so the verify loop needs zero dashboard clicks. `POST /api/push/target` requires a
`campaignId` and is not needed for verification.

Two caveats to carry honestly:
- `devices[]` (with `endpointEnabled`, `appPackageName`) is documented in the help center but
  **absent from the Swagger schema** — the spec's `ApiResponseUser` is incomplete. Treat the
  shape as observed-behaviour and assert defensively.
- "Push integration named X exists and is healthy" is **not** API-checkable. `GET /api/channels`
  returns only `{id, name, messageMedium, channelType}`; `GET /api/messageTypes` only
  message-type metadata. Read-back requires the browser, or a test-send as a proxy.

### The browser agent question, answered

Two separate answers, because two things are true at once.

**The broad answer:** the right class is **DOM / accessibility-tree**, not screenshots.
Screenshot-based computer use costs ~1,000–1,800 input tokens *per screenshot* and is far too
slow and expensive for a multi-dozen-step console workflow.

**The specific answer:** a genuinely new category shipped in mid-September 2026, and it is worth
naming precisely because it will be tempting.

- **Jev** (TypeSafe, announced 2026-09-15) is a **"System One model"** — not a browser tool. It
  takes a *state* plus *typed questions* and returns structured values (`Choice`, `Score`,
  `Noul`) with probability distributions and calibrated confidence. No text generation, no
  parsing. Early-access reports put it near half a cent per call.
- **`jev-ultrafast`** (browser-use, 2026-09-17, MIT) applies Jev to browsing. Each observation
  regenerates a numbered element table; Jev returns an operation plus a target index in **one
  network round trip** (`CLICK`, `TYPE_TEXT`, `SELECT`, `SCROLL_*`, `WAIT`, `DONE`, `BLOCKED`).
  No screenshots in the default loop. Measured: median 9.45s → 7.09s, browser protocol calls
  **1,092 → 101**.
- **The opposite thesis, from the same org two days earlier.** browser-use's "The Bitter Lesson
  of Browser Agents" (2026-09-15) argues you should *stop* pre-digesting the page: hand the
  model raw CDP and let it choose its own observations, because any fixed representation loses
  something (their example: a visible button absent from the accessibility tree; a control in a
  closed shadow root). Their single `browser_exec` tool cut mean token usage **60%** with Opus
  4.8 and **66%** with Kimi K3, at 18/18 successful runs.

**Why none of this changes the primary choice yet:**

1. **`jev-ultrafast` lists file upload as out of scope**, along with iframes, shadow roots, and
   pop-up tabs. Uploading the FCM service-account JSON into Iterable's form is the single most
   important browser action in this tool. That alone rules it out as the driver.
2. Maturity: two commits, no releases, and a benchmark the authors themselves qualify as "three
   repeats of one task on one browser profile."
3. It adds two vendor dependencies (a TypeSafe key and a separate text-model key).

**And why the tier design makes this a deferrable choice rather than a bet.** Tier 2 — the
recorded script — is where ~95% of runs live, and it spends zero model tokens. That is the same
prize Jev is chasing, won a different way. Jev and `browser_exec` compete only for **Tier 3**,
the rare drift-healing path. So this is an A/B to run later, not an architecture decision to
make now. Revisit when `jev-ultrafast` supports file upload, or evaluate it for the read-back
gates below, where upload is not needed.

**One idea worth adopting now, independent of which driver wins.** Jev's typed-question output
is a better primitive for *reading pages back* than prompting a chat model and parsing prose.
"Is the FCM message type set to Data notifications?" is precisely a typed `Choice`/`Noul` with
calibrated confidence — and a low-confidence answer should route to the human rather than
silently pass a gate. Worth an evaluation task against the G11/G12 read-backs.

**Primary: Playwright MCP** (`@playwright/mcp`, verified at 0.0.81). Operates on structured
accessibility snapshots — text, compact, no vision model. Verified flags that matter here:

| Flag | Why it matters |
|---|---|
| `--extension` | Connects to the developer's **already-running real Chrome**. They log in themselves; we never touch their password, and Google sees a genuine browser. |
| `--user-data-dir <path>` | Persistent profile — log in once, reuse the session across runs |
| `--cdp-endpoint` | Fallback: attach to Chrome started with `--remote-debugging-port` |
| `--allowed-origins` / `--blocked-origins` | Confine the agent to the three consoles. Not a security boundary, but a strong guardrail against wandering. |
| `--secrets <dotenv path>` | Values never enter the model's prompt |
| `--save-session`, `--output-dir` | Per-run audit trail |
| `--codegen typescript` | **Emits replayable Playwright code from the agent's actions** |
| `--isolated`, `--storage-state` | Clean CI runs from a saved session |

**Fallback: Chrome DevTools MCP** (`chrome-devtools-mcp`, verified 1.9.0) — same DOM-based
speed, attaches to a running Chrome, adds network/performance inspection for debugging a
stuck form.

**Rejected:** screenshot/vision agents (Computer Use, Skyvern) — too slow and expensive here.
Claude in Chrome — an extension the developer drives, not something this CLI can orchestrate,
and it carries a domain blocklist we cannot audit.

`--codegen` is the single most important finding for cost and speed, and it drives the tier
model below.

### The Android proof is feasible and fast

- Emulators **do** receive real FCM, given a Google APIs or Google Play system image. On this
  machine: `system-images;android-34;google_apis_playstore;arm64-v8a` and friends are already
  installed, and an emulator is already running.
- Full cycle — boot, install, token, send, assert — is **~90–120s**.
- Iterable's SDK uses **data-only** messages, so `onMessageReceived` fires but no notification
  is auto-posted. The assertion must therefore be a **logcat marker from a hook in the fixture
  app**, not `dumpsys notification`. `dumpsys` is a secondary check only.
- Known flake sources with fixes: launch the app once so it leaves "stopped state"; whitelist
  it from doze; wait for Play Services after boot.

---

## Architecture: four tiers, in strict preference order

```
Tier 1  DETERMINISTIC      gcloud / firebase CLI / REST / Iterable public API
        ↓ only if no API exists
Tier 2  REPLAYABLE SCRIPT  recorded Playwright spec, no model in the loop
        ↓ only if the script breaks on UI drift
Tier 3  BROWSER AGENT      Playwright MCP, accessibility tree; re-derives and
                           re-records the Tier-2 script as its output
        ↓ only if a human is genuinely required
Tier 4  HUMAN              ASK.md, exit 10, resume on next invocation
```

Tier 2 is what makes this cheap in steady state: the agent solves the Iterable dashboard
*once*, `--codegen` captures it, and every subsequent run replays deterministic code. The
model is paid for only on drift — and when it drifts, its job is to produce a new recording,
so the system heals rather than degrades.

**Tier 4 is not a failure mode, it is a designed interface.** Four things are legitimately
human: Google Cloud ToS acceptance, Google sign-in, Iterable sign-in, and any CAPTCHA or
org-policy block. The tool must not try to defeat any of them.

---

## The gate ladder — how we know we reached the end goal

Eighteen gates. Each is a pure read with a single boolean answer, run independently of the step
that produced the state. `iterable-onboard status` prints the ladder with the first red gate
highlighted; that gate is always the next thing to work on.

| # | Gate | Verified by |
|---|---|---|
| G0 | Tooling present | `node`, `gcloud`, `adb`, `java` resolve at required versions. **Not `firebase`** — see below |
| G1 | Google authenticated | `gcloud auth print-access-token` succeeds **and** the token survives one real API call. Never a config read — see below |
| G2 | GCP project exists | `gcloud projects describe $PID` |
| G3 | Firebase enabled on it | `GET firebase.googleapis.com/v1beta1/projects/$PID` succeeds |
| G4 | Android app registered | `GET /v1beta1/projects/$PID/androidApps` contains `$PACKAGE` |
| G5 | `google-services.json` sane | parses; `project_info.project_id == $PID`; a `client[]` entry's `package_name == $PACKAGE`; `api_key` non-empty |
| G6 | Service account exists | `gcloud iam service-accounts describe` |
| G7 | FCM role bound | `get-iam-policy` shows the member with `roles/firebasecloudmessaging.admin` |
| G8 | Key file sane | parses; `type == service_account`; `project_id == $PID`; `private_key` present; mode `0600` |
| G9 | **Key actually works** | mint token from key → `messages:send` `validate_only: true` → 200 |
| G10 | **Iterable API keys work** | you create them in **Settings > API Keys**; server key → `GET /api/channels` == 200 and ≥1 Push channel; mobile key → `POST registerDeviceToken '{}'` authenticates (400, not 401); a deliberately invalid key must answer 401 or the probe proves nothing. Keys live in `.env` mode `0600` |
| G11 | Iterable mobile app exists | **not a gate.** No endpoint reads it back. Printed `~ unverifiable`; proved indirectly by G16 |
| G12 | Push integration configured | **not a gate.** Same reason. Printed `~ unverifiable`; proved indirectly by G16 |
| G13 | App installed with the SDK | `dumpsys package` — version, install time, `IterableFirebaseMessagingService` resolves, `POST_NOTIFICATIONS` granted. **Reads the device, not a build** — see below |
| G14 | FCM token obtained | `logcat` — the last `registerDeviceToken` and the code Iterable answered. Silence is `pending`, never red |
| G15 | Token registered in Iterable | `getByEmail` → `devices[]` entry matching `$PACKAGE` with `endpointEnabled == true` |
| G16 | **Push arrives on device** | `dumpsys notification` — a record for `$PACKAGE` carrying the marker `bin/proof-push` sent |
| G17 | Iterable agrees it sent | `GET /api/events/{email}` shows `pushSend`, not `pushSendSkip`/`pushBounce` |

### Corrections from the real walk-throughs (2026-09-18)

Found by running the ladder against a real account. The first two were defects in this plan rather
than in an implementation; the later ones were defects in code that only a live call or a real
terminal could expose.

**G1 was a decorative gate.** As originally written — "`gcloud auth list` has an active account;
ADC present" — it passed on a machine whose credentials were *expired*: the account was listed,
`application_default_credentials.json` was present at `0600`, and
`gcloud auth print-access-token` failed with `Reauthentication failed`. The run would have gone
green at G1 and died at G2 with a raw gcloud stack trace instead of writing a clean `ASK.md`.

The general rule this implies, and it applies to every gate: **a gate that reads local
configuration is not a gate.** Presence of a credential is not proof of a working credential.
Every gate must make the smallest real call that would fail if the state were wrong. Audit the
whole ladder against this — G1 was not necessarily the only one written this way.

**The `firebase` CLI is not required.** Adding Firebase to a project, registering an Android app,
and fetching `google-services.json` are all reachable over `firebase.googleapis.com` REST with a
gcloud access token. Dropping it removes a global Node install from the prerequisites, which
directly lowers the chance G0 blocks a customer. G0 no longer checks for it.

**Cascade noise made the output useless, and conflated two exit codes.** One dead credential
produced three separate twelve-line gcloud reauth traces, because every downstream gate ran
anyway and re-reported the same root cause. Fixes, all in `bin/gates`:
- **A third gate state.** `blocked` ≠ `failed`. A gate downstream of a red prerequisite says
  nothing about the system, so running it only burns API calls and buries the real message.
  Gates that need no credentials (local file checks) still run, because they stay informative.
- **One-line diagnostics.** Tool output is collapsed to ~100 useful characters.
- **Exit 10 vs 20 decided by owner, not by severity.** Each gate declares whether a human or the
  tool clears it. G1 red is exit `10` plus a written `ASK.md`; a mismatched package name in
  `google-services.json` is exit `20`. Without that split, a cron loop cannot distinguish
  "waiting on a person" from "broken", which is the entire reason the tool has two codes.

**Creating resources is now opt-in, and the default assumption was backwards.** The plan was
written as though the tool creates a Firebase project. In reality **an Android developer
integrating Iterable almost always has Firebase already** — they have a shipping app, so they
have a project, an app, and a `google-services.json`. Project creation is the *rare* path.

So the defaults invert: `bin/provision` requires an existing project and refuses to create one
unless `CREATE_PROJECT=1`; likewise `CREATE_APP=1` for registering an Android app. Against an
existing project, G2–G5 are **pure reads**, and the only mutations in the whole Google side are
adding a service account and its key — both trivially removable. That is a much easier thing to
ask a customer to run, and it makes the common path the safe one.

`bin/discover` (pure read) lists the developer's Firebase projects and the Android apps in each,
so the package name is *discovered from live state* rather than typed into `inputs.yml` and
mistyped. The resolved choice is cached in `workspace/resolved.env` so the actor and the verifier
cannot disagree about which project they are describing.

G10 is deliberately **first** in the Iterable half: it is the cheapest dashboard interaction, so
it fails fast if the session is dead or the key is the wrong type, before anyone spends time on
the app and the integration form. It is also a clean actor/verifier split — a human creates the
key, and a plain API call proves it.

**Definition of done: G16 green. G17 corroborates it only on the campaign path** — see the
2026-09-21 correction below; a proof send raises no `pushSend` event, so G17 has nothing to read
unless `ITBL_CAMPAIGN_ID` is set. G9 and G16 remain deliberately *independent* proofs — G9 proves
the credential in isolation, G16 proves the whole chain. A run that reaches G9 but fails G16
localises the fault to the Iterable side; the reverse is impossible and would indicate a bug in
the gates themselves.

**`firebase.googleapis.com` needs a quota project, and not just any one.** User credentials get a
flat `403` from this API unless the request carries `x-goog-user-project`. The gcloud CLI attaches
one implicitly, which is why `gcloud projects list` works while the same token in a raw `curl`
does not — a confusing failure, because the credential is fine. Every request in `bin/config.sh`
now sends the header.

Choosing *which* project cost a second correction. The first fix assumed any project the developer
can see would satisfy Google; it does not. A project without the Firebase Management API enabled
answers `403 SERVICE_DISABLED`, and the fallback happily cached one, so a first run with no project
chosen yet failed at the project picker. Every Firebase project has the API enabled by definition,
so `firebase_projects()` now walks candidate quota projects and keeps the **first one that answers
the real call**, caching that. The cached quota project is therefore proven rather than assumed —
the same principle as G1. Cold start costs ~2.7s against a 25-project account.

**The project picker has to be offered, not inferred.** The wizard originally showed its menu only
when `workspace/resolved.env` had no project — so a second run silently reused the earlier choice,
and the first implementation had picked the project on the developer's behalf anyway. Now the
Firebase phase always shows the remembered choice and asks whether to keep it, and the picker is
two explicit stages: Firebase project, then the Android app registered inside it. Listing projects
is one API call; the app list is one more. The old `scan_candidates` helper, which probed 25
projects to build a flattened project×package menu, is deleted — `bin/discover` uses the same
one-call listing and now returns in ~7s.

**G9 failed on the first real `--apply`, and the cause was eventual consistency.** A
service-account key is not usable the instant `keys create` returns: Google's token endpoint
answers `Invalid JWT Signature` until the public key propagates, measured at **64s** on Franco's
run. Because `bin/provision` creates the key and immediately `exec`s `bin/gates`, a first run
would fail G9 essentially always — while the ladder reported it as "a real defect, not a missing
prerequisite", which was the most misleading thing the tool has said so far.

Ruling out the alternative mattered here, because the error names the signature and the signing is
hand-rolled. Verified the JWT signing is correct independently: `bin/sa-token.js` self-verifies
against its own key pair, uses base64url throughout, and the `private_key_id` in the file matches
the `USER_MANAGED` key Google lists. Sixty seconds later the identical key minted a token. So the
signature was never malformed.

The fix lives in the **verifier**, not the actor: `mint_sa_token()` retries only on that one error
string, only while the key file is young, and only to a bounded deadline — so "not yet" is
distinguished from "broken" and a genuinely bad credential still fails fast. `bin/provision` warns
that G9 may pause, since an unexplained 60-second silence is its own kind of defect. Putting the
wait in the actor was rejected: waiting until the key works *is* G9's proof, and the actor must not
perform it. `tests/key-propagation.sh` covers both branches with a fabricated key, so the retry is
testable without waiting for a real propagation window.

The general rule, and a counterweight to the one above: **a gate must not report eventual
consistency as a defect.** "A gate must make a real call" and "a gate must not fail on a race with
the API it just called" are both required; a gate against a freshly mutated resource needs a
bounded retry on the specific not-yet error, and on nothing else.

**The same race exists one layer up, in IAM, and the first fix missed it.** After the key
propagation fix, a run against a fresh project failed G9 with
`403 Permission 'cloudmessaging.messages.create' denied`. Ruled out the obvious causes first:
`roles/firebasecloudmessaging.admin` really does include that permission, the binding really was
in the policy, and `fcm.googleapis.com` really was enabled. Seventy-four seconds later the same
key succeeded. So a **new role binding takes ~75s to become effective** — and G7 is green
throughout, because the binding genuinely is in the policy. G7 is not wrong; it just cannot
answer the question G9 asks.

The first fix had wrapped only the *token mint*, so it could not see a failure that happens at the
send. G9 now retries the whole proof — mint plus send — against one deadline, on either
not-yet signal. Two design points earned here:

- **The three-way judgement is a pure function.** `classify_fcm_response()` takes a status and a
  body and returns green / red / not-yet with no network, so `tests/fcm-classify.sh` can pin it to
  response bodies recorded from real runs — including the 403 above, and the *other* 403
  (`API has not been used in project…`) which must **not** be retried. Two identical statuses,
  opposite verdicts, decided only by the body: exactly the logic worth testing offline, and
  untestable while it was buried in a curl pipeline.
- **A retry that gives up must still report the cause.** The first refactor replaced
  `Invalid JWT Signature` with a tidy `key not propagated yet`, which reads better and tells the
  developer nothing once the retry has been exhausted. The not-yet messages now carry the
  underlying error, and the fixture asserts that they do.

**`cmd | grep -q` is unsafe under `set -o pipefail`.** `grep -q` exits on the first match, the
upstream command takes SIGPIPE, and the pipeline reports failure on what was actually a *match*.
This silently skipped the propagation fixture on a ladder that was green, and had just been
introduced into provision's new-binding check, where it would have mislabelled an existing binding
as fresh. All four occurrences now capture the output first and match against a here-string. The
API-enablement loop got faster in passing: one `services list` for five APIs instead of five.

**Fixing the quota header on reads only, and a swallowed exit status, combined into one
misleading failure.** `api_get` got the `x-goog-user-project` header; the two raw `curl -X POST`
calls in `bin/provision` did not, so registering an Android app came back `403`. Worse, both POSTs
piped into `head -c 400` and **ignored the exit status entirely**, so the 403 printed and then
execution fell through into the "wait for the long-running operation" loop, which timed out and
reported `app did not appear`. The tool named the symptom furthest from the cause.

Three fixes, in increasing order of how much they prevent: `api_post` now exists alongside
`api_get` with identical auth and quota handling; both call sites check the status and stop; and
`tests/no-raw-http.sh` fails the build if any file outside `bin/config.sh` talks to a
`googleapis.com` URL through a raw `curl`. The last one is the real fix — **one wrapper per verb
means one place to get the header right**, and the test is what stops the next verb from drifting.
`bin/gates` keeps its direct `fcm.googleapis.com` POST, explicitly exempted, because G9 must prove
the service-account token in isolation rather than reuse a user-credential helper.

`api_err()` now extracts the single useful sentence from Google's twenty-line error bodies, since
the raw JSON was itself part of why the real cause was hard to see.

**Per-project state outlived the project it belonged to.** Switching from `android-sdk-tester-franco`
to a new project left `APP_ID` from the old one in `resolved.env` (the write was
`grep -q || echo >>`, so it only ever wrote the value once) and left the old project's
`sa-key.json` in `workspace/artifacts/`. The stale `APP_ID` turned out to be harmless — the actor
recomputes it from live state before use — but the stale key was not: provision's G8 skipped on
mere file existence, so it would leave the correct key uncreated and let G8's own project check
take the blame. Now `save_resolved()` is the single writer for `resolved.env` (and clears a key when
given an empty value), the wizard clears `APP_ID` when a new project is chosen, and provision moves
a key belonging to another project aside rather than trusting it. Moved, not deleted: the file is
the only local copy of a live credential.

The general shape, worth watching for in G10–G17: **anything derived from the target must be
invalidated when the target changes.** Cached derived state that silently survives a switch is the
same class of bug as a gate that reads config instead of calling the API — both report on a world
that no longer exists.

**A menu reading its choice from stdin spins forever.** `printf … | menu` leaves `menu`'s stdin at
EOF once it has drained the option list, so `read choice` returned empty immediately and the
"not a valid choice" loop never terminated. It reads from `/dev/tty` now. This bug survived every
syntax check and every non-interactive run: it is only reachable from a real terminal, which is the
argument for driving the wizard through a pty (`expect`) in CI rather than trusting `bash -n`.

### First live run of the Iterable half (2026-09-21)

Ran G10–G17 against real keys for the first time, on `dog-shelter-ai-one-shot` / `com.dogshelter`.
**G10 green, including `control 401`** — so the auth-before-validation assumption behind the `{}`
probe is now *observed* rather than argued for. Three defects came out of the same run.

**The status code never reached the gate.** `itbl_req` echoed the body and *set* `ITBL_CODE`, so
every call site wrote `body="$(itbl_get …)"` — a command substitution, therefore a subshell — and
the status died with it. Under `set -u` the next line failed with `ITBL_CODE: unbound variable`.
The transport now sets `ITBL_CODE` and `ITBL_BODY` on the caller and returns nothing on stdout, and
`itbl_curl` is split out so `tests/itbl-transport.sh` can stub it and assert the split offline.
The general shape: **a function that returns one value through stdout and another through a global
has an untestable contract** — the caller has to know not to capture it, and nothing enforces that.
So the test also lints for the old pattern, and that lint is checked by injecting the pattern and
confirming it fails.

`tests/itbl-classify.sh` could not have caught this: it feeds `classify_itbl_response` literal
codes and never exercises the plumbing that produces them. Pinning a pure function is cheap and
worth doing, and it proves nothing about how the function gets its arguments.

**A fourth gate state: `notbuilt`, and exit 40.** G15 went red with "No user exists with email …"
and the ladder announced "a real defect, not a missing prerequisite". Both halves of that were
wrong: the cause was that G14 — the gate that puts a token on the device — isn't written yet, so
the run blamed the customer's Iterable project for a hole in our own code. `todo()` now prints
G13/G14/G16 as unimplemented, they never count as green, G15/G17 correctly show `waiting on G14`,
and the run exits **40** — "nothing is broken and nothing is proven". Note that `gate()`'s own
comment had already anticipated `G10,G14` as G15's prerequisite; the wiring said `G10` only
because G14 did not exist to depend on. **A prerequisite that cannot be expressed gets dropped
silently, and the gate then fails for the wrong reason.**

**G17 waits on G14, deliberately not on G16.** Coupling the corroborator to the thing it
corroborates would silence the one gate that can explain a G16 failure — `pushSendSkip` and
`pushBounce` are precisely what you want to read when no push landed.

### A push actually landed, and it cost the plan two assumptions (2026-09-21)

Full chain run end to end for the first time, on the Dog Shelter app (`com.dogshelter`,
`dog-shelter-ai-one-shot`): onboard provisioned the Google side, the `iterable-android` skill did
the SDK integration, **G15 went green live** (`1 enabled device(s) for com.dogshelter`), and a real
push arrived on the emulator. Two assumptions in this plan turned out to be wrong.

**`templates/push/proof` does not raise a `pushSend` event, so G17 cannot corroborate it.** The
plan called proof "the unlock: it sends to a user without a campaign or a list, so the verify loop
needs zero dashboard clicks." That is true of *sending* and false of *verifying*. Measured: a proof
send that demonstrably reached the device produced **zero** push events on `/api/events/{email}` —
4 events total, all in-app, none mentioning push — re-checked over 7 minutes, so this is not
latency. `POST /api/push/target` would raise the event, but it requires a `campaignId`, i.e. a
dashboard click, which is the cost proof was chosen to avoid.

So the corroboration is **conditional, not free**: G17 is a gate when `ITBL_CAMPAIGN_ID` is set and
a `note()` otherwise. Leaving it as an unconditional gate would park every successful proof run at
"not done" forever. The wider lesson, and it is the same one as G1: **"an API exists for X" is not
"the API answers the question the gate asks."** The endpoint inventory was right; the inference
from it was not.

**The OS is a better witness than the app.** G16 was specified as a logcat marker,
`ITBL_E2E_PUSH:<id>`, which requires an instrumented fixture app. `adb shell dumpsys notification`
proved the arrival instead, reporting `pkg=com.dogshelter` with the template's own title and body.
That is strictly better: the notification service is neither the sender nor the app, so it cannot
be fooled by either, and **it needs no code in the customer's app at all**. G16 can therefore
verify the developer's real app rather than a fixture — which removes Task 5's fixture-app
dependency from the critical path. Build G16 on `dumpsys`, and keep the logcat marker only as an
optional extra for token capture at G14.

One packaging note for whoever builds G16: `templates/push/upsert` returns the new id only inside a
prose string — `{"msg":"Upserted 1 templates with IDs: 26219806"}` — so it has to be parsed out of
`msg`, not read from a field.

### The Iterable half is hand-driven (2026-09-21)

Built G10→G17 minus the device gates. Three corrections to the plan came out of it.

**Verified by absence, not assumed.** Fetched all 131 paths from
`https://api.iterable.com/api-docs` and searched them: there is no endpoint to create an API key,
create a mobile app, or configure a push integration — and every endpoint the *proof* needs does
exist. That is a much stronger statement than "we couldn't find one", and it is what settled the
design: the human clicks exactly three things, and nothing else in the tool needs a browser.
Each operation also carries `x-iterable-api-key-types`, so `tests/key-types-match-spec.sh` now
checks the key type each gate sends against the live spec rather than against our belief.

**A step with no read-back is not a gate — gate rule 4.** G11 and G12 were specified as "browser
read-back". Reading a local file, or a screen, to decide that a remote step happened is the false
pass this whole tool exists to prevent. So `bin/gates` grew a fourth state: `note()` prints `~
unverifiable` and says why, and the summary line counts *verifiable* gates only. G11/G12 are
proved indirectly — if G16 lands a push, both were right.

**A gate that cannot fail is worse than no gate.** G10's mobile-key probe posts `{}` to
`registerDeviceToken`: a 400 proves the key authenticated without creating a device, and a 401
means the key is bad. That inference only holds if Iterable authenticates before it validates, so
the gate immediately repeats the call with a deliberately invalid key and requires 401/403. If the
invalid key answers the same as the real one, the gate goes red on "I can't tell" rather than
passing. Same instinct as G1: prove the instrument can move before trusting the reading.

**Not reverse-engineered, on purpose.** Replaying the dashboard's internal calls was considered
and rejected: it requires escalating from a scoped API key to the human's session credential,
EN-1023 ("Fine-Grained API Key Permissions" — `resourceActions` replacing key types, scope
immutable after create) is actively rewriting the key-creation screen, so today's internal
endpoints are a moving target, and we can simply ask the owning team instead.

### The device half, and what the OS will and won't say (2026-09-21)

Built G13, G14 and G16 — the last three stubs — and with them the ladder ran **15 of 15 green,
exit `0`**, end to end, against a real project and a real emulator. G16 matched `bin/proof-push`'s
own marker on the device 2 seconds after the send. That is one run, on one app, by the person who
wrote the tool: it establishes that the ladder can reach its own definition of done, not that a
stranger's project can.

**A gate must read the device, not the source tree.** G13 was specified as "builds and installs",
which tempts a gate into running Gradle and believing the exit code. The APK *on the device* is what
receives the push, so G13 reads `dumpsys package` instead and never builds anything. The find that
made it a real gate: `dumpsys package` lists resolved services, so
`com.iterable.iterableapi.IterableFirebaseMessagingService` appearing there is device-side proof
that the installed binary carries the SDK. That catches "integrated the SDK, forgot to reinstall" —
a morning nobody gets back, and invisible to any check that reads the repo.

**Two ways to read `granted=false`.** `POST_NOTIFICATIONS` denied and never asked look identical in
the permission dump except for `flags=[ USER_SET ]`. Denied is red — the push will arrive and never
be shown, which is the most confusing failure in the whole ladder. Never asked is `pending`. Same
distinction as G15's "no user yet", and the same rule: never report a not-yet as a defect.

**logcat is asymmetric evidence, so G14 cannot be chained to anything.** The ring buffer rotates
within hours, so G14 can prove registration happened and can *never* prove it didn't — absence is
`pending` forever, and after a deadline it reports "still not after Ns" rather than "broken". Which
means G14 and G15 can legitimately disagree: a token registered yesterday is invisible to G14 and
plainly there for G15. G15 therefore does **not** wait on G14. Chaining them would let the weaker
witness silence the durable one.

Two parsing notes for anyone touching `bin/token-log.js`: the SDK logs the request and the response
from **different tids**, with unrelated `======` separators interleaved between them, so the
response must be matched by grouping on tid rather than by scanning forward; and only the *last*
registration attempt counts, because a relaunch re-registers and an old failure followed by a fresh
success is a pass.

**`dumpsys notification` needs `--noredact`, and dismissal erases the evidence.** Without the flag
the content reads `android.title=String [length=18]`, which cannot be matched against a marker. And
`mArchive=Archive (0 notifications)` is not a formality: the first live G16 read nothing because
force-stopping the app to capture registration logs had cleared its notification. The oracle is the
live list only. `AggregatedStats{key='<pkg>', … numBlocked=N}` in the same dump is what explains a
"sent but never shown" — worth reporting, never worth guessing at.

**Deleting a state is a result too.** `bin/gates` had a fifth state, `notbuilt`/`todo()`, so that an
unwritten gate could never be mistaken for a green one. It is gone: the three gates it existed for
are built, and a state that describes the tool rather than the subject should not outlive its reason.
`bin/onboard`'s exit-`40` advice now derives the next action from `state.tsv` instead of naming those
gates as unbuilt.

**The secret lint was matching a proxy.** `tests/no-raw-http.sh` banned the whole `ITBL_` prefix from
`resolved.env` as a stand-in for "secret", and the proxy started failing honest code — the proof
marker and template id are values the ladder prints in its own verdict, so `resolved.env` is exactly
where they belong. It now matches credential-shaped names, and injects `save_resolved
ITBL_SERVER_KEY` into a temp file to prove the narrowed pattern still catches a real key. A lint
nobody has seen fail is a lint nobody knows works.

**A cache must not outrank the caller.** `config.sh` used to `source resolved.env`, which silently
overrode the environment: `PID=other bin/gates` read the remembered project and reported gates about
an app nobody asked about. It now loads key by key and skips anything already **defined** — even
defined empty, so `TARGET_DEVICE= bin/gates` is how you forget a remembered choice.

### What a first real trial found (2026-09-21, later the same day)

Franco ran the tool himself, which is worth more than any amount of re-reading it. Three findings,
none of them in the half that had just been tested.

**A device needs a picker, not an instruction.** The ladder said `2 devices attached — say which:
export ANDROID_SERIAL=emulator-5554`. Correct, and useless: a port number is not something anyone
recognises as their own device, and being told to go export a variable is the "run something and
come back" the wizard exists to avoid. So the wizard now picks — listing AVD names, offering AVDs
that aren't running and booting the one you choose, **and asking even when there is exactly one
attached**, because a phone left plugged in to charge is still the wrong device to prove a push on.
`bin/gates` still never prompts; it names all the candidates and exits. The remembered choice is the
AVD name rather than the serial, since emulator serials are handed out in boot order.

**"Any email address" was a lie in the prompt.** `bin/iterable-keys` asked for a test user as
though it were free-form. It is the join key between the app and Iterable: the SDK files the token
under whatever the app passes to `setEmail()`, and the proof push goes to `ITBL_EMAIL`. Franco typed
a different address than the app signs in with, and G15 duly reported "no user yet" — which reads
exactly like a broken Iterable project and is not one. The prompt now says what the value has to be,
and G15's verdict names the other possibility.

**A verdict cut mid-word reads like the whole verdict.** `brief()` truncated at 100 characters with
`cut`, which ended G15's new remedy at "...signs in as a different addres" — the half that says what
to do, gone silently. It now cuts on a word boundary and appends an ellipsis, and it moved to
`config.sh` so a test can reach it without running the ladder.

Two verdicts were also lying by construction, in opposite directions. The wizard ran the Google
half, found nothing to provision, and printed **"Done — and verified, not assumed"** when no push
had been proven; and once G16 did go green while something else was pending, the ladder still said
**"No push has been proven"**. Both now read the state instead of the exit code: `push_proven()`
asks G16, and the wizard's rc-40 branch says what is pending instead of offering to provision
nothing. The lesson is the plan's own, turned on the reporting layer — an exit code says *something*
is pending, never *what*, and a summary that infers the rest will eventually infer wrong.

### Two follow-ups, and what the second one cost to test (2026-09-21, end of day)

`ITBL_EMAIL` was settled by asking the server rather than by picking the likeliest spelling. Three
candidates had accumulated across runs; `getByEmail` answered 200 with one enabled GCM device for
`com.dogshelter` on exactly one of them and 400 on the other two. The ladder then went **15 of 15,
exit 0**. Worth keeping as a habit: the join key has an authority, and it isn't the developer's
memory or the tool's cache.

**The boot-failure branch is now executed, and getting there found a lie next to it.** The branch
lived in `bin/wizard`, reachable only by a human choosing a stopped AVD, which is why three attempts
to drive it through a pty failed. Moving `boot_avd` into `config.sh` — the same move `brief()` needed,
for the same reason — made it a function a test can call. Three cases now run offline in about 8
seconds with a stubbed `emulator` and `adb`, `BOOT_WAIT=3 BOOT_POLL=1`: an AVD that comes up, one that
attaches to adb but never sets `sys.boot_completed`, and one that never attaches at all. The middle
case is the one worth having — it is the only thing that proves the wait is on the OS rather than on
the port, and adb answering early is exactly how a half-booted device gets read by a gate.

The lie was the next line down. On a failed boot the wizard said "the device gates will wait for it",
and they do not: `bin/gates` never waits for anything, by design, because it has to stay safe to
drive from a loop. It now says the device is remembered and that G13 onwards will report it as not
running. Third instance of the same defect class in two days — a message describing behaviour the
code doesn't have. Cheap to write, invisible to every test that doesn't read the prose.

---

### "The emulator doesn't even show up" — why a green G16 can look like nothing happened (2026-09-21, evening)

Asked for visual confirmation, the device produced a contradiction: `dumpsys` had the proof record,
G16 was green, and four screenshots in a row showed an untouched app. The OS settled it —
`airtimeMs=5698, posttimeToFirstVisibleExpansionMs=516, isNoisy=true, mImportance=HIGH` — the banner
had been on screen for 5.7 seconds. Screenshot polling kept landing outside that window; a
`screenrecord` sampled at 2fps caught it in one frame.

But the first two attempts genuinely showed nothing, and that part was real. **Android groups a second
notification from the same app with the first and marks the children `SILENT`** — verified directly:
`flags=AUTO_CANCEL|SILENT` on both children under an `AUTOGROUP_SUMMARY`, where a lone proof carries
only `AUTO_CANCEL`. So the second proof push of a session arrives, satisfies G16, and produces no
banner and no sound. To anyone judging the integration by watching the screen — which is what a
developer does — that is indistinguishable from a push that never came. `bin/proof-push` now warns
when an earlier proof is still in the shade, and G16 states the age of the arrival once it is over ten
minutes old, because re-running the ladder does not re-send and the green can be hours stale.

Clearing the shade from the CLI has no obvious command; `cmd notification` offers no dismiss. Two that
do work: `cmd notification list` plus `snooze --for <ms> <key>` (the key contains `|`, so it needs
quoting for the *device's* shell or it is parsed as a pipe), and `set_exempt_th_force_grouping`, which
is the grouping behaviour itself. Snoozing is not clearing — snoozed notifications come back when the
timer expires, which is how a shade "cleared" for one test had six proofs in it twenty minutes later.

**The warning on the actor was in the wrong place.** Reported again as "it says arrived on the device
but it didn't really, maybe it's reading an old value", and the first thing to check was whether the
gate fabricates: with an empty shade it reports `·` pending, so it does not. The push had arrived,
silently, and `bin/proof-push` had said so — but the complaint came from reading `bin/gates`, which
had not. A caveat only the actor prints is invisible to anyone who runs the verifier, which is the
normal way to use this tool.

So G16 now carries both facts itself: `"G16 proof itbl-onboard-1789996750" at 2:19:13 PM, 2s after
send — SILENT, no banner`. It reads `flags` off the record, and it states the age of every arrival
rather than only stale ones — the earlier ten-minute threshold existed to fit `brief()`, which is a
formatting reason for withholding the one fact that reconciles a green gate with a developer who saw
nothing. Quoting only the notification's text, not its title as well, buys back the characters.

The general rule: **when the tool and the developer disagree about reality, the verdict is what has to
explain the difference.** "Arrived" and "I saw nothing" were both true here, and only the gate was in
a position to say why.

**The test identity should never have been a free-text prompt.** It was typed wrong three times across
runs — `franco@testemail.com`, `francotest@emailtest.com` — and each time G15 read "no user yet", which
looks like a broken Iterable project. The authority was on the device all along: the SDK logs its own
`registerDeviceToken` body, `"email": "test@useremail.com"`. `app_identity()` reads it and
`bin/iterable-keys` offers it as the default. Worth noting what didn't work: the app has no login
screen, and no such literal appears in its dex, so neither reading the UI nor unpacking the APK would
have answered it. The request body did.

Same shape as the device picker — the developer can't be expected to recall a value the machine
already knows, and the fix is to offer it rather than ask for it. Silence stays silence: nothing
registered yet means no default, because a guessed identity is worse than a question.

## Testing strategy

The gates tell us whether a *run* succeeded. These tests tell us whether the *gates* can be
trusted — which is the part that usually gets skipped.

### Level 1 — negative fixtures (the load-bearing tests)

A verifier that always returns `true` passes every happy-path test. So each gate ships with a
poisoned fixture it **must** reject. These are drawn directly from the skill's documented
pitfalls, which is the point: every silent failure the skill warns about becomes a red gate.

| Fixture | Must fail |
|---|---|
| `google-services.json` with a mismatched package name | G5 |
| `google-services.json` from a different Firebase project | G5 |
| SA key with the IAM binding removed | G9 (403 from FCM) |
| Malformed / truncated SA key | G8 |
| SA key belonging to a **different** project than `google-services.json` | G9 passes, **G16 fails** — the cross-project mismatch trap |
| `endpointEnabled: false` on the device | G15 |
| FCM type set to **Notification messages** instead of Data | **G16** — the app never sees `onMessageReceived`. This is the highest-value trap in the whole flow. |
| Key file at mode `0644` | G8 |
| Mobile key used where a server key is required (and vice versa) | G10 — the two key types are not interchangeable, and the failure otherwise surfaces much later as a confusing 401 |
| JWT-enabled mobile key with no captured shared secret | G10 — the secret is shown once at creation; if we missed it, say so immediately rather than failing at G15 |

If the cross-project and wrong-FCM-type fixtures do not produce red gates, the tool is not
finished, regardless of how many happy paths pass.

### Level 2 — offline runner tests (CI, no credentials, no cost)

Shim `gcloud`/`firebase`/`adb` on `PATH` with fakes that replay recorded fixtures. Exercises
the whole state machine, resume logic, and exit codes with no Google account and no money
spent. Runs on every commit.

**The wizard must be driven through a pty here, not just syntax-checked.** Its prompts, menus,
and consent path are unreachable without a terminal, and the `/dev/tty` menu bug above proves
`bash -n` says nothing useful about them. `expect` (present on macOS and every CI Linux image)
spawns `bin/wizard`, answers each prompt, and asserts the transcript. The load-bearing case is
answering **no** at the consent prompt and then asserting that nothing changed — the wizard's
central promise is that it does not touch anything before you agree.

### Level 3 — dashboard selector canary (daily)

The single biggest fragility is Iterable dashboard UI drift silently breaking Tier 2. A daily
job replays the recorded scripts in read-only mode against the sandbox project and fails
loudly on drift. This converts silent breakage into a dated alert, and is the trigger for a
Tier-3 re-record.

### Level 4 — live end-to-end (nightly + on demand)

Full ladder G0→G17 against the real Iterable sandbox project and a disposable GCP project,
then teardown. Note for teardown: deleted GCP projects enter a 30-day soft-delete and count
against project quota, so recycle a small pool of test projects rather than creating one per
run.

### Level 5 — cold-start human trial

`skeptical-client-dev` runs the tool with no context, as a customer would, and reports where
it was confusing, presumptuous, or asked for something it should have derived. Per prior
project convention, this real-life trial — not an eval score — is the signal that gates
shipping.

---

## Metrics — the optimization objective

Every run writes `workspace/runs/<ts>/report.json`. Four numbers matter:

1. **TTFP** — wall-clock from cold start to G16 green. The headline number.
2. **Human-touch count** — how many times the tool blocked. The floor is **3** as built: Google
   ToS/sign-in, Iterable sign-in, and one pass through `bin/iterable-keys` covering the three
   dashboard steps that have no API. Two of those are authentication we deliberately refuse to
   automate; the third is unavoidable until the API exists (open question 2). Anything above 3 is
   a bug in the automation, not a fact of life.
3. **Tier-3 agent actions** — browser-agent steps taken. Target **0** in steady state;
   non-zero means the UI drifted and a re-record is due. This is the cost line.
4. **Gate flake rate** — gates that pass on retry without any state change. Anything above
   zero is an untrustworthy gate.

Optimising this tool means driving 1 and 3 down while holding 2 at its floor and 4 at zero.

---

## Workspace — what the human owns

`workspace/` is gitignored. Everything in it is either yours to fill or the tool's to write.
Nothing in the tool ever reaches outside it.

```
workspace/
  inputs.yml        ← YOU: package name, app name, project ids, region, FCM type, test email
                      (still reference only — the wizard asks for these and records the
                      answers in resolved.env; no code reads this file yet)
  .env              ← TOOL writes the Iterable keys it created (0600). Pre-fill only if you
                      already have keys and would rather the tool reused them.
  chrome-profile/   ← YOU: log in once (Google + Iterable); reused after that
  ASK.md            ← TOOL writes blockers here; you answer, then re-run
  state.tsv         ← TOOL: gate results + resume point, one id/status pair per line
  resolved.env      ← TOOL: choices safe to print — project, package, app id, proof marker.
                      Never a credential; tests/no-raw-http.sh enforces that
  artifacts/        ← TOOL: google-services.json, sa-key.json (0600), apk
  runs/<ts>/        ← TOOL: report.json, logs, playwright session trace
```

Exit codes, so a loop or cron can react without parsing output:

| Code | Meaning |
|---|---|
| `0` | All gates green — a push reached the device |
| `10` | Blocked on a human — `ASK.md` written |
| `20` | A gate failed — a real defect, details in the run report |
| `30` | Tool error |
| `40` | Nothing is broken and nothing is proven — a gate ran and the state simply hasn't happened yet |

**The self-running loop:** `iterable-onboard run --resume` → hits a human-only step → writes
`ASK.md` → exits `10`. You do the one thing it asked. Next tick resumes from that gate. No
babysitting, no silent guessing, no work redone.

---

## The team

Committed to `agents/` in this repo (not `.claude/`, which the skill repo gitignores) and
linked into `~/.claude/agents/` via `make link-agents`, so the roster is reproducible.

| Agent | Model | Owns | Tools |
|---|---|---|---|
| `onboard-architect` | opus | Gate ladder, state machine, tier decisions | Read, Edit, Write, Bash |
| `gcp-provisioner` | sonnet | Google side: gcloud/firebase/REST, ADC, org-policy failures | Read, Edit, Write, Bash |
| `web-operator` | sonnet | **Only agent with browser tools.** Drives the consoles, emits Tier-2 recordings | Playwright MCP, Read, Write |
| `iterable-api-client` | sonnet | Public API client, key verification (G10), the G14–G17 verify loop | Read, Edit, Write, Bash |
| `harness-engineer` | sonnet | Emulator lifecycle, fixture app, logcat assertions | Read, Edit, Write, Bash |
| `gate-auditor` | opus | **Adversarial verifier.** Owns the negative fixtures; independently re-derives whether a gate is truly green | Read, Grep, Glob, Bash *(read-only)* |
| `skeptical-client-dev` | *(existing)* | Cold-start customer trial | — |
| `iterable-sdk-pm` | *(existing)* | Owns TTFP and human-touch count | — |

Two structural rules:
- **`gate-auditor` never performs a provisioning action**, and no agent that acted may audit
  its own gate. That separation is the whole reason to have a team rather than one agent.
- **`web-operator` is the only agent with browser access**, and it is confined by
  `--allowed-origins` to `console.firebase.google.com`, `console.cloud.google.com`,
  `app.iterable.com` (plus the EU host when configured).

---

## Build order

Each task ends with a runnable check. Nothing proceeds on an unverified assumption.

**Task 1 — skeleton + state machine + `status`.** `inputs.yml` schema, `state.json`, gate
registry, exit codes, `iterable-onboard status` printing the ladder. Check: `status` on an
empty workspace prints 18 red gates and exits `20`.

**Task 2 — G0/G1 and the ASK.md handshake.** Tooling detection, `gcloud auth` check, the
block-and-resume path. Check: with no `gcloud` auth, exits `10` and writes an `ASK.md` that
names the exact command to run.

**Task 3 — Google provisioning, G2→G8.** `gcp-provisioner`. Idempotent throughout: re-running
against an existing project must be a no-op, not an error. Check: from an authenticated
account, produces a valid `google-services.json` and key, all gates green.

**Task 4 — G9, the credential proof.** Mint a token from the key, `messages:send` with
`validate_only`. Check: passes with the real key; fails with the role-removed fixture.

**Task 5 — the device gates, G13→G14.** *Built 2026-09-21, and the fixture app turned out to be
unnecessary.* `bin/gates-device.sh` reads the developer's own installed app over `adb`:
`dumpsys package` for G13, `logcat` for G14, with the verdicts in `bin/token-log.js` as a pure
function over a dump so they can be tested offline. No fixture app, no emulator lifecycle, no hook
in anyone's source. A minimal fixture app is still the only way to test the *Android* half of the
`iterable-android` skill in isolation — it is just not on this tool's critical path.
Check: `tests/device-token-log.sh`, offline, over recorded logcat. ✅

**Task 6 — the proof send and the arrival, G15→G17.** *Built 2026-09-21.* `bin/proof-push` upserts a
template, sends the proof, and records the marker — then stops, because the actor never grades its
own work. G16 reads `dumpsys notification` for that marker; G17 is a gate only with
`ITBL_CAMPAIGN_ID` set. Check: a real push landed on the emulator and G16 matched it 2s later;
`tests/device-notify.sh` pins the verdict offline, including the stale-marker and blocked cases. ✅

**Task 7 — the hand-driven Iterable half, G10→G12.** *Re-scoped 2026-09-21 and built ahead of
Tasks 5–6, since it needs no device.* `bin/iterable-keys` walks the human through the three
dashboard steps and captures the two keys with echo off; `bin/gates-iterable.sh` proves G10, G15
and G17 by API; G11 and G12 print `~`. No browser automation. Check: the four tests pass offline
(`itbl-classify`, `key-types-match-spec`, `no-raw-http`, `wizard-decline`) and the ladder reports
G10 red with the remedy named, not a false green. **Closed 2026-09-21:** G10 and G15 have now run
green against real keys; G17 is conditional by design.

**Task 7b — the browser tier, deferred.** Recording `/settings/apiKeys` under `--codegen` is a
convenience layer over a working hand-driven path, and EN-1023 is about to rewrite that screen.
Worth doing only once the scoped-key UI settles.

**Task 8 — negative fixtures and the offline runner.** All Level-1 and Level-2 tests.
Check: every poisoned fixture produces the expected red gate; CI passes with no credentials.

**Task 9 — the canary and the cold-start trial.** Level 3 daily job; `skeptical-client-dev`
runs it blind. Check: a deliberate selector change is caught within one day.

Tasks 1–6 are the deterministic spine and are worth building first even if the browser tier
is deferred: they already replace the most error-prone half of the setup guide and produce
the two hardest-won artifacts.

---

## Risks, and what we do about them

| Risk | Mitigation |
|---|---|
| **Iterable dashboard UI drift** breaks Tier 2 | Daily selector canary; Tier-3 agent re-records rather than one-off patching |
| **Google blocks automated sign-in** | We never automate sign-in. `--extension` into the developer's real Chrome; they authenticate themselves |
| **Org policy blocks SA key creation** | Detect `constraints/iam.disableServiceAccountKeyCreation` and route to Tier 4 with the exact console URL. Do not retry blindly |
| **The SA key is a long-lived credential** | `0600`, gitignored, never logged; offer deletion after upload; state plainly what it grants |
| **Chrome profile holds live Google cookies** | Gitignored, local-only, documented as sensitive |
| **`firebase login:ci` deprecation** | Do not build on `FIREBASE_TOKEN` at all |
| **Emulator flake** | Launch app out of stopped state, disable doze, wait for Play Services, bounded retries |
| **Iterable's stance on dashboard automation** | **UNRESOLVED — open question below.** Do not ship customer-facing until answered |
| **The tool now mints Iterable API keys** | Narrowest available scope, recognisable names, recorded in the run report, teardown offered. Values go to `.env` at `0600` and are never logged or echoed — including in the Playwright trace, which must be scrubbed or disabled for the key-creation step |
| **Betting Tier 3 on a two-day-old agent framework** | Tier 3 is a pluggable fallback behind Tier 2, not the spine. Evaluate `jev-ultrafast`/`browser_exec` behind an interface; ship neither until file upload and domain scoping are proven |

---

## Open questions

Questions 1 and 6 no longer block anything (2026-09-21). Both were about the tool acting on the
customer's behalf in the dashboard, and it no longer does: the human clicks, the tool reads. They
come back the moment Task 7b is picked up, so they stay on the list.

1. **Does Iterable's ToS or acceptable-use policy permit customers to drive `app.iterable.com`
   with a browser agent?** *No longer blocking* — nothing drives the dashboard today. Still needs
   a PM/legal answer before Task 7b (the recorded browser tier) ships to a customer.
2. **Should we ask for a provisioning API instead?** *Now the main ask.* Confirmed by absence
   across all 131 public paths: there is no endpoint for creating an API key, a mobile app, or a
   push integration, which is precisely why three human clicks are irreducible. `iterable-admin-cli`
   already proves the in-house pattern for CLI↔SSO auth (OAuth 2.0 device flow, RFC 8628,
   credentials at `~/.iterable/admin-cli.json` mode `0600`). EN-1023 is rewriting key creation
   anyway, so the ask is well-timed: land `resourceActions` keys with an API, not just a new
   screen. Worth raising with the platform team regardless of what we build here.
3. **Which Iterable sandbox project and keys** will the live tests use, and who owns them?
4. **EU region.** `app.eu.iterable.com` and the EU API host need their own recordings and a
   config switch. In scope for design, deferred in implementation.
5. **Should the tool create a JWT-enabled mobile key?** Default is no, because it is the
   shortest path to a verified push and the shared secret is shown only once. But the skill
   treats JWT as mandatory once enabled, so a developer who will ship with JWT should get a JWT
   key from the start rather than a second setup pass. Needs a recommendation from the SDK team
   on what the default should be for a *customer* run, as distinct from an internal test run.
6. **Is a tool creating API keys on the customer's behalf acceptable?** *Moot for now* — the tool
   mints nothing; the human creates both keys and pastes them into a `0600` file. It returns with
   Task 7b, and the answer then is the same shape: scope them as narrowly as the dashboard allows,
   name them recognisably (e.g. `onboard-tool-<date>`), record what was created in the run report,
   and offer teardown. Needs the same PM/security answer as question 1.
