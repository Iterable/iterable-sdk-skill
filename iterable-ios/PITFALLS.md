# Iterable iOS SDK — Agent Pitfalls

Silent failures and integrations that look correct in Simulator but fail under
real signing, delivery, logout, or account-switch conditions. The hot-path
rules live in `SKILL.md`; use this file when implementing or diagnosing the
matching behavior.

The findings below come from controlled integration trials, SDK source review,
and Iterable's documentation corpus.

## 1. Release shares an `aps-environment = development` entitlement

- **Symptom:** Debug registration works, but an archive, TestFlight build, or
  production Test Push fails signing, produces the wrong token environment, or
  never arrives.
- **Cause:** One entitlement file hardcodes `development` and is assigned to
  both Debug and Release. A simulator build does not expose the distribution
  mismatch.
- **Fix:** Let signing provide the effective entitlement or use
  configuration-specific source settings. Inspect both Debug and Release.
  Development builds use the sandbox/development environment; distribution
  builds use production. Keep `IterableConfig.pushPlatform = .auto` unless a
  confirmed legacy integration requires otherwise.

## 2. The active user at tap time is treated as the notification recipient

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

## 3. A notification permission callback mutates the next user's session

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

## 4. A direct Test Push is used to claim logout or targeting works

- **Symptom:** A notification sent directly to a copied device token still
  arrives after logout, so the developer concludes `logoutUser()` failed—or a
  direct delivery is treated as proof that user association works.
- **Cause:** Iterable's direct **Test Push** targets the APNs token itself and
  bypasses user/profile association.
- **Fix:** Use direct Test Push only to prove the APNs credential, environment,
  bundle ID, token, and device-visible delivery. Use a user-targeted test
  message to prove identity association, logout disablement, and account
  switching.

## 5. No safe way to distinguish APNs failure from Iterable registration failure

- **Symptom:** No device appears in Contact Lookup, and the evaluator cannot
  tell whether iOS failed to produce a token or Iterable failed to register it.
- **Cause:** The app forwards the token but provides no local diagnostic, while
  normal logs intentionally avoid complete tokens.
- **Fix:** First inspect the intended user's matching device in **Audience >
  Contact Lookup**. If it is absent, provide a DEBUG-only token diagnostic that
  keeps the token in memory until explicitly requested. If copying is offered,
  use a local-only pasteboard item with a short expiration. Compile the
  diagnostic out of Release and never persist or capture the complete token in
  repository evidence.

## 6. General pasteboard token copy is described as non-persistent

- **Symptom:** A DEBUG screen says the APNs token is memory-only or
  non-persistent, but its copy action assigns the complete value to
  `UIPasteboard.general.string`.
- **Cause:** The general pasteboard may retain the item beyond the immediate
  app interaction and may make it available through Universal Clipboard.
- **Fix:** Prefer the token shown in Contact Lookup. For the fallback
  diagnostic, keep the token in memory until explicit access and use
  `UIPasteboard.setItems` with `.localOnly: true` and a short
  `.expirationDate`. Tell the developer the clipboard is temporary, clear it
  after use when practical, and compile the entire diagnostic out of Release.

## 7. Launch or action handling bypasses recipient validation

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

## 8. SwiftUI `onOpenURL` enters a trusted personalized route

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

## 9. A skipped SDK initialization leaves an Apple callback unfinished

- **Symptom:** The app remains buildable without an API key, but a matching
  Simulator-injected notification leaves response completion and app-owned
  routing approval pending indefinitely.
- **Cause:** The wrapper skips `IterableAPI.initialize` but still calls
  `IterableAppIntegration.userNotificationCenter`. Calling the integration
  boundary before initialization can leave the supplied completion handler
  pending. The background integration method can similarly have no initialized
  implementation to complete the callback.
- **Fix:** Track initialization state at the SDK boundary. When unavailable,
  call the original response or fetch completion directly and clear app-owned
  approval. Add tests for matching responses and silent delivery with an empty
  or rejected key.

## 10. Privacy copy lists only app-selected fields as all Iterable data

- **Symptom:** The app says Iterable receives only selected profile fields and
  business events.
- **Cause:** The disclosure omits normalized identity, SDK-managed push
  registration and device/app/OS metadata, notification state, and standard
  push or in-app engagement.
- **Fix:** Describe app-supplied identity, profile, and event fields separately
  from SDK-managed device registration and engagement data. Keep local clearing
  and logout distinct from server-side deletion.

## 11. XcodeGen writes Push capability metadata as a string

- **Symptom:** Entitlements are present, but the generated project contains a
  quoted `SystemCapabilities` value or no Push capability marker.
- **Cause:** Some XcodeGen versions stringify nested target attributes instead
  of emitting the PBX dictionary expected by Xcode.
- **Fix:** Inspect the generated `project.pbxproj`. Use a supported generator
  representation, or a checked deterministic normalizer that accepts one
  already-correct dictionary, rewrites one known malformed shape, and fails on
  missing, duplicate, or unknown shapes. Keep configuration-specific
  entitlements and background modes as source-controlled functional inputs;
  the marker does not replace signing proof.

## 12. SwiftUI attaches the notification response handler after launch

- **Symptom:** Warm notification taps work, but a terminated-app tap sometimes
  completes without routing.
- **Cause:** The app delegate is installed before launch returns, while its
  response collaborator is assigned later from SwiftUI `onAppear`. If the app
  also strips remote-notification launch options, the early Apple callback is
  the only routing path and gets dropped.
- **Fix:** Construct or attach every response-path collaborator before
  `didFinishLaunchingWithOptions` returns, or buffer the complete response until
  app state is ready. Test cold-start ordering; a nil handler must not silently
  discard a verified response.

## 13. Restored profile fields are dropped before SDK initialization

- **Symptom:** The restored user is identified, but targeting fields such as
  favorites remain missing or stale until the next mutation.
- **Cause:** Pre-initialization identity is queued, while profile updates simply
  return. Initialization replays only identity.
- **Fix:** Queue one coherent restored identity/profile snapshot and replay it
  after successful initialization. Test restoration with an initially
  unconfigured SDK boundary, then initialize and assert identity and profile
  updates are both sent.

## 14. Notification permission exists only in a settings screen

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

## 15. URL routing reads observable session state off the main actor

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

## 16. Simulator support is confused with local notification injection

- **Symptom:** The integration either demands a physical iPhone for every
  development run, or claims Iterable/APNs delivery after `simctl push`.
- **Cause:** Older guidance treats all Simulator notification behavior as
  local-only. Apple supports real APNs sandbox registration and delivery on an
  iOS 16+ Simulator when the Mac runs macOS 13+ and Xcode 14+ on Apple silicon
  or Intel with a T2 chip. `simctl push` remains a separate local injection
  path and reaches the same app callback surface.
- **Fix:** Classify the validation target and transport explicitly. An eligible
  Simulator with `aps-environment = development` can prove real APNs sandbox
  registration and delivery when the runtime token appears on the intended
  Iterable user and a uniquely marked Test Push arrives. `simctl push` proves
  only local callback handling. Production and TestFlight validation still
  require a physical iPhone.
