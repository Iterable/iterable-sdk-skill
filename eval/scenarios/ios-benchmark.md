# iOS benchmark rules — Sample Shop trials

These rules come from the controlled iOS integration trials (the Sample Shop
adoption app: email identity, favorites, adoption alerts, several accounts on
one device). They are that product's policy plus the scoring bar for
[`ios.yml`](ios.yml). **They are not requirements for every Iterable iOS
integration**, so the shipped `iterable-ios` skill no longer imposes them; a
benchmark run supplies them in its prompt or reads them from here.

Platform foot-guns that apply to every app stay in
[`iterable-ios/PITFALLS.md`](../../iterable-ios/PITFALLS.md).

## Completion gates for a benchmark run

Before a benchmark run counts as complete, every applicable gate holds:

- **Recipient-bound foreground push:** `willPresent` applies the same opaque
  recipient/session policy as response handling. Missing, mismatched, and
  logged-out notifications do not display personalized content.
- **Generated Push capability:** for the known XcodeGen malformed shape, the
  run copies
  [`iterable-ios/assets/normalize-xcodegen-push-capability.rb`](../../iterable-ios/assets/normalize-xcodegen-push-capability.rb)
  rather than a custom grep/substitution, proves that correct and malformed
  input pass while missing, duplicate, and unknown shapes fail, and runs the
  valid result twice with unchanged bytes.
- **Contextual permission dismissal:** an undecided first-value explanation
  cannot close through swipe or a generic **Done** without persisting the
  product's **Not Now** choice.
- **Observable routing:** identity/session validation and navigation execute
  together on the main actor, with a background-callback regression test.
- **Logout:** visible personalized state and pending routing/permission work
  clear before the Iterable logout/network call.
- **Real configuration:** the app initializes with a securely captured and
  independently validated Mobile API key whose region and JWT policy match the
  recorded scope.
- **Runtime connection:** the exact test identity appears in Iterable after the
  app identifies it; when events or profile updates are selected, at least one
  agreed value appears on that user.
- **Proof boundary:** local `simctl push` injection and unsigned builds never
  become claims of APNs, Iterable delivery, device registration, or
  attribution. An eligible iOS 16+ Simulator proves APNs sandbox delivery;
  production/TestFlight requires a physical iPhone.

A green build or unit suite that does not exercise these is incomplete.

## Recipient-bound notification routing

The trial app lets several people sign in on one iPhone, so a notification
meant for User A must not open personalized content, or be attributed, after
User B signs in. Iterable's standard push metadata identifies campaign,
template, and message — not the recipient — so the app carries its own
recipient in the template's custom raw payload.

- Put an app-owned **opaque** recipient identifier in the payload. Avoid raw
  email or other direct personal data; production apps prefer a backend-issued
  stable identifier. A per-install UUID written to one user-level profile field
  breaks multi-device users (each device overwrites the last) and is acceptable
  only for a documented one-device benchmark.
- Validate the complete `UNNotificationResponse` **before** forwarding it to
  `IterableAppIntegration.userNotificationCenter`: forwarding records the push
  open under the SDK's current identity before app-owned URL routing runs, so
  blocking only the URL is too late.
- Inspect `response.actionIdentifier` first. A dismiss with no product-defined
  dismiss action completes without forwarding, navigation, or fallback. For
  default and custom actions, compare the recipient with the active identity and
  session generation; a missing or mismatched recipient takes the safe app
  fallback and completes without forwarding. A verified response is forwarded
  once, and Iterable chooses the default or custom-button action.
- Keep push-routing approval active until the SDK completion handler runs, bind
  it to the recipient and the initiating session generation, and invalidate it
  on logout and every identity transition — including same-user re-login.
- In the `IterableURLDelegate`, a `.push` URL requires active approval. Apply
  separate policy to `.inApp` and `.embedded`; treat `.universalLink` and
  `onOpenURL` as external entry points, not recipient proof.
- Don't pre-route `defaultAction` and then also let Iterable route the same
  response. The SDK may defer a remote-notification launch action until the
  root UI exists, so a gate that ends right after `initialize` expires too soon;
  if the app validates launch data itself, don't also hand the unvalidated
  remote-notification launch option to the SDK.
- `content-available` background delivery is not a user selection and must not
  navigate.
- Apply the same ownership check in `willPresent`: an unverified notification
  normally gets empty presentation options.

Tests cover the orchestration boundary, not only a `userInfo` helper: default,
dismiss, and custom action identifiers; missing, matching, and previous-user
recipients; background and terminated activation; delayed launch routing;
logout; skipped initialization; delayed SDK completion across logout and
same-user re-login; external custom-scheme opens; silent delivery; direct
`IterableURLDelegate.handle(iterableURL:inContext:)` source mapping; and a
cold-start test that the response collaborator exists before SwiftUI view
appearance. Keep Apple delegate methods thin, inject the policy/SDK adapter,
and pair adapter unit tests with a Simulator-injected notification that reaches
the public Apple callback.

## Contextual notification permission

The trial product asks for adoption alerts after the user saves a first
favorite.

- Connect the accepted domain action to the app-owned explanation; a
  notification button in Settings alone does not satisfy the product.
- **Not Now** skips the system prompt and persists at the product's chosen
  scope. Decide device versus identity scope explicitly; a device-global "never
  ask again" is wrong when each account controls its own preference.
- While undecided, every dismissal is disabled or behaves as **Not Now**. Once a
  preference exists, a plain close may dismiss the manual settings view.
- Keep a manual control for later recovery, and test the trigger from the real
  action boundary.
- Bind `getNotificationSettings` / `requestAuthorization` callbacks to the
  initiating identity/session and revalidate on completion; logout or an
  account switch invalidates pending work. Test denial, errors, and a callback
  arriving after logout or user switching.

## Restored identity and profile state

If the app restores identity plus targeting fields (favorites) before the SDK is
ready, queue one coherent snapshot and replay both after initialization. Test
with an initially unconfigured SDK boundary.

## Instrumented runtime proof

Only for an explicitly requested benchmark: copy
[`iterable-ios/assets/IterableRuntimeProof.swift`](../../iterable-ios/assets/IterableRuntimeProof.swift)
into a dedicated evaluation configuration and follow
[`iterable-ios/guides/runtime-proof.md`](../../iterable-ios/guides/runtime-proof.md).
Two fresh identities, the exact `.app`, the selected device, and visible
tap/logout expectations are recorded up front; the run proves callback
ordering, restore, tap handling, logout ownership, and the User B control. If
the app applies a recipient policy in `willPresent` or its tap handler, the
proof payload carries the matching recipient field.

## Pitfalls moved out of `PITFALLS.md`

These keep their `iterable-ios/PITFALLS.md` ids — that file leaves a stub at
each — so checks in [`ios.yml`](ios.yml) that cite them still mean the same
thing. The text is as it was when they moved.

### Pitfall 2. The active user at tap time is treated as the notification recipient

- **Symptom:** User A receives a notification, logs out, User B signs in, and
  tapping A's old notification opens personalized content or records the open
  under B.
- **Cause:** The app captures its current session when the tap occurs and calls
  that proof of ownership. Standard Iterable iOS push metadata contains
  campaign, template, message, and test/proof state—not the intended recipient.
  A partial fix may block only URL navigation and still forward the response to
  Iterable. Forwarding can track the push open using the SDK's current identity
  before app-owned URL routing runs, so the rejected open can still be
  attributed to User B.
- **Fix:** When routing is recipient-bound, put an app-owned opaque recipient
  identifier in the template's custom raw payload. Compare it with the active
  user before routing or tracking. Missing or mismatched identifiers use the
  product's safe fallback and must not be forwarded to Iterable under the
  current identity. Apply the same ownership policy before foreground
  presentation; normally suppress an unverified banner rather than showing the
  previous account's message. For a verified response, forward it once and
  keep the routing approval active until the SDK completion handler runs. Do
  not put raw email or direct personal data in the payload; production apps
  should prefer a backend-issued stable opaque identifier.

### Pitfall 3. A notification permission callback mutates the next user's session

- **Symptom:** User A starts a notification status or authorization request,
  logs out or switches accounts, and the eventual callback presents A's prompt,
  stores A's choice, or registers notifications while User B is active.
- **Cause:** Clearing visible prompt state does not cancel
  `getNotificationSettings` or `requestAuthorization`. The callback applies its
  result without checking the identity/session that initiated it.
- **Fix:** Capture an identity or generation token for every asynchronous
  permission operation and revalidate it on completion. Logout and user
  switching invalidate pending work. Test a delayed callback after both flows,
  including the error branch.

### Pitfall 7. Launch or action handling bypasses recipient validation

- **Symptom:** Warm default taps look correct, but a terminated-app launch,
  dismiss action, custom action button, or silent notification routes the wrong
  URL, resets navigation, or escapes the app's ownership check.
- **Cause:** The app pre-routes `defaultAction` from `userInfo`, ignores
  `response.actionIdentifier`, or ends a routing gate immediately after SDK
  initialization. The SDK may defer launch-option handling until the root UI is
  available. Treating every remote launch payload as a user response also turns
  silent `content-available` delivery into navigation.
- **Fix:** Validate the complete notification response before forwarding it.
  Handle dismiss explicitly without navigation or fallback. Validate default
  and custom actions, keep validated push-routing context alive through SDK
  completion, and do not pass the same unvalidated remote launch payload into a
  later automatic path. A `.push` URL delegate callback must require active
  approval, including if it arrives after response completion. Silent delivery
  must not navigate. Test background and terminated activation,
  default/dismiss/custom actions, delayed launch routing, and the public app and
  URL delegate boundaries.

### Pitfall 8. SwiftUI `onOpenURL` enters a trusted personalized route

- **Symptom:** Opening a valid custom URL from Safari, another app, or
  `simctl openurl` reaches personalized content even though no recipient
  ownership accompanied the URL.
- **Cause:** The app shares URL parsing but collapses source trust, sending
  every `onOpenURL` value directly into a route intended for a verified
  Iterable notification or in-app message. The same collapse can happen when
  an `IterableURLDelegate` ignores `IterableActionContext.source`.
- **Fix:** Keep URL source and trust explicit. Public destinations may be
  allowed by product policy. Personalized destinations from `onOpenURL` require
  their own ownership proof; without it, discard or use the product's safe
  fallback. Require active recipient approval for `.push`, and define separate
  policy for `.inApp`, `.embedded`, and `.universalLink`. Test the external
  custom-scheme entry point independently from the Iterable URL delegate.

### Pitfall 13. Restored profile fields are dropped before SDK initialization

- **Symptom:** The restored user is identified, but targeting fields such as
  favorites remain missing or stale until the next mutation.
- **Cause:** Pre-initialization identity is queued, while profile updates simply
  return. Initialization replays only identity.
- **Fix:** Queue one coherent restored identity/profile snapshot and replay it
  after successful initialization. Test restoration with an initially
  unconfigured SDK boundary, then initialize and assert identity and profile
  updates are both sent.

### Pitfall 14. Notification permission exists only in a settings screen

- **Symptom:** The app has a working permission manager and a manual
  notification control, but the promised contextual explanation never appears
  after the user reaches the product's value moment.
- **Cause:** The implementation builds the permission UI in isolation and does
  not connect it to the accepted domain action, such as saving the first
  favorite. A direct unit test of the permission manager still passes.
- **Fix:** Trigger the app-owned explanation from the accepted action boundary.
  **Not Now** must avoid the system prompt and persist at the intended identity
  or device scope. Keep a manual control for later recovery, and test the real
  action-to-explanation flow. While the preference is undecided, disable
  generic swipe/**Done** dismissal or make it persist the same **Not Now**
  choice; otherwise the explanation can recur on launch without a recorded
  decision.

### Pitfall 15. URL routing reads observable session state off the main actor

- **Symptom:** Navigation appears to work, but Thread Sanitizer or strict
  concurrency reports races during a push or URL callback. Logout and account
  switching can also interleave with a stale session check.
- **Cause:** The router reads identity, favorites, or another
  `ObservableObject`/`@Published` property on the callback thread, then
  dispatches only the final navigation mutation to the main queue.
- **Fix:** Move the complete observable-state operation—including session
  validation and navigation—onto the main actor. Add a focused test that calls
  the URL or routing boundary from a background queue and proves the check and
  mutation execute safely together.
