# Iterable SDK skills

> **Private beta.** Use of these skills is subject to Iterable's
> [Beta Terms](https://iterable.com/legal/beta-terms/). This documentation is
> confidential, may contain inaccuracies, and may change during the beta.

Use these skills with Claude Code, Cursor, or Codex to integrate Iterable's
native Android, native iOS, or React Native SDK. The workflows gather and prove
the required external prerequisites before calling an integration complete.

The plugin runs under your coding assistant. The provisioning workflow asks
before reading or changing scoped cloud resources.

## Included skills

| Skill | Purpose |
|---|---|
| `iterable-provision` | Produces and verifies Firebase, Apple, APNs, and Iterable prerequisites for the selected platform. |
| `iterable-android` | Integrates and troubleshoots Iterable's native Android SDK using version-pinned documentation. |
| `iterable-android-verify` | Independently verifies native Android and React Native Android integrations and push delivery. |
| `iterable-ios` | Integrates and troubleshoots Iterable's native iOS SDK using Iterable documentation and iOS lifecycle guidance. |
| `iterable-ios-verify` | Independently verifies a native iOS, React Native iOS, or Expo iOS integration, using no-app-edits behavioral proof by default and optional instrumented diagnostics. |
| `iterable-react-native` | Integrates and troubleshoots `@iterable/react-native-sdk`, including Expo projects. |

The skills can work independently. A new push integration normally follows:

`iterable-provision` → platform integration skill → matching platform verification skill

Skills are model-invoked. Describe the outcome you want rather than running a
skill by name. For example:

- "Set up Iterable push notifications in this app."
- "Integrate Iterable's React Native SDK."
- "Why isn't my push notification arriving?"
- "Verify that this integration works on my emulator."
- "Verify this existing iOS integration without changing the app."

## Supported workflows

- Native Android SDK integration.
- Native iOS SDK integration.
- React Native integration for Android and iOS, including Expo.
- Firebase provisioning and device-side push verification for Android.
- Apple/APNs prerequisite guidance and iOS runtime proof.
- Push notifications, in-app messages, mobile inbox, embedded messaging, deep
  links, JWT authentication, event tracking, and user profiles.
- Unknown user activation for native Android and native iOS.

Web SDK integration is not included.

## Requirements

### Accounts

- An Iterable project. The provisioning skill can guide you through creating
  the required Iterable API keys and mobile configuration.
- A Google account with access to a Firebase project, or permission to create
  one, when setting up Android push.
- Apple Developer Program access to the app's team when setting up native iOS
  push. The workflow cannot replace Apple sign-in, 2FA, agreements, or the
  one-time download of a newly created APNs private key.

You authenticate with Google and Iterable yourself. The plugin does not ask for
or handle your account passwords.

### Command-line tools

The provisioning and verification workflows require these non-standard tools:

```bash
node --version
gcloud --version
adb --version
xcodebuild -version
```

| Tool | Used for | Installation |
|---|---|---|
| `gcloud` | Google authentication, Firebase projects, service accounts, IAM, and key creation | [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) or `brew install --cask gcloud-cli` |
| `adb` | Selecting an Android device and reading the installed app, SDK registration, and arriving notification | Android Studio's SDK Manager or `brew install --cask android-platform-tools` |
| Xcode command-line tools | Building, signing, installing, and observing native iOS apps | Install Xcode, then select it with `xcode-select` |
| Node.js | Parsing command and API output | [nodejs.org](https://nodejs.org) or `brew install node` |

The scripts also use Bash, `curl`, and standard Unix utilities. They do not
install or modify your JDK, Gradle, Android SDK, or Node.js toolchain. During
integration, your coding assistant may run your project's existing build and
install commands with your approval.

If a required tool is missing, the workflow reports which tool is needed and
stops without attempting to install it.

### Test device

Device-side verification requires a connected Android device or a running
emulator with Google Play services. You select the target device, even when
only one is connected, so the proof is performed on the device you intend to
test.

For native iOS, development push can be proved on an eligible booted iOS 16+
Simulator or a signed physical iPhone. Production/TestFlight proof requires a
physical iPhone.

During native iOS push setup, the developer chooses whether to reuse an
existing Apple configuration, follow a guided Account Holder or Admin
handoff, or let an App Store Connect Team API key register the App ID and Push
Notifications after an approved plan. The imported APNs key is checked with
one APNs sandbox probe. No extra tools are needed beyond Node, curl, and Xcode.

## Installation

### Claude Code

```text
/plugin marketplace add Iterable/iterable-sdk-skill
/plugin install iterable-sdk@iterable
```

Start a new Claude Code session after installation. Skills are loaded when a
session starts.

To receive updates automatically, open `/plugin`, select **Marketplaces**,
select **iterable**, and enable auto-update.

### Cursor

Cursor requires version 3.9 or later. Clone the repository and link the skill
directories:

```bash
git clone --depth 1 https://github.com/Iterable/iterable-sdk-skill.git ~/iterable-skills
mkdir -p ~/.cursor/skills
for skill in iterable-provision iterable-android iterable-android-verify iterable-ios iterable-ios-verify iterable-react-native; do
  ln -sfn ~/iterable-skills/$skill ~/.cursor/skills/$skill
done
```

Run **Developer: Reload Window**, then start a new Agent chat.

### Codex

```bash
codex plugin marketplace add Iterable/iterable-sdk-skill
codex plugin add iterable-sdk@iterable
```

Start a new Codex session, then use `codex plugin list` to confirm that the
plugin is installed.

For local development, use the repository checkout as the marketplace source:

```bash
codex plugin marketplace add .
codex plugin add iterable-sdk@iterable
```

## What happens during Android push setup

1. The integration skill inspects the application and adds the required SDK
   configuration.
2. If Firebase or Iterable prerequisites are missing, the provisioning skill
   explains what it needs to read and asks for permission before continuing.
3. The workflow creates or selects the Firebase resources and service account.
4. It guides you through the Iterable dashboard actions that do not have a
   public API: API keys, the mobile app, and the Firebase push integration.
5. Your coding assistant builds and installs the application using the
   project's existing toolchain.
6. The workflow opens the selected application's launcher activity. You sign in
   as the test user and respond to any Android permission prompts.
7. The verification skill sends a proof notification and checks Android's
   notification service to confirm that it arrived.

The component that performs an action does not verify its own result. For
example, the sender records which proof notification it sent, while a separate
read-only verifier checks the device for that notification.

## Security and data handling

- The repository's scripts run locally and make authenticated HTTPS requests
  to Google, Firebase, and Iterable.
- You authenticate in your own browser or `gcloud` session. The scripts do not
  collect account passwords or attempt to bypass sign-in, CAPTCHA, or
  terms-of-service screens.
- Secrets are designed to move through protected files, environment variables,
  or the local clipboard workflow rather than through chat, logs, or command
  arguments.
- The generated `.iterable/` workspace is kept inside your project and
  gitignores itself. It can contain credentials and should be treated as
  sensitive.
- The verification gates only read application and notification state.
  Separate actors can open or foreground the selected app or system surface,
  but they do not tap, type, sign in, or answer permission prompts.

Your coding assistant runs with your local privileges. Its handling of source
code and conversation data is governed by the assistant provider and your
organization's configuration. Install plugins only from sources you trust.

## Current limitations

- Firebase provisioning is Android-specific. Native iOS uses Apple/APNs
  prerequisite guidance and supports Simulator or physical-device proof within
  the documented environment limits.
- Creating Iterable API keys, mobile apps, and push integrations requires
  dashboard interaction because these actions do not have public APIs.
- Core verification can run for a JWT-enabled integration, but the app's JWT
  backend behavior requires separate feature-specific evidence.
- Some bundled source articles cover multiple mobile platforms and may include
  snippets that are not relevant to the current application.
- These skills focus on SDK integration. To work with campaign or user data,
  use Nova Agent in Iterable or
  [Iterable's MCP Server](https://support.iterable.com/hc/articles/42936800222612).

## Updating

For Claude Code, update the marketplace before updating the plugin:

```text
/plugin marketplace update iterable
/plugin update iterable-sdk@iterable
```

Start a new session after updating. With auto-update enabled, Claude Code may
ask you to reload plugins after a newer version is downloaded.

For Cursor's clone-and-link installation:

```bash
cd ~/iterable-skills
git pull
```

Then reload the Cursor window and start a new Agent chat.

## Contributing and architecture

Repository-maintenance commands are documented in
[`CONTRIBUTING.md`](CONTRIBUTING.md). In particular, Docs team members can use
the copy-review workflow there to render onboarding questions without
credentials, network access, or a connected device.

Engineering references:

- [`bin/README.md`](bin/README.md) — onboarding program architecture.
- [`INTENDED-FLOW.md`](INTENDED-FLOW.md) — authoritative onboarding sequence.
- [`REVIEW.md`](REVIEW.md) — generated SDK documentation review.
