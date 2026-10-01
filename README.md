# Iterable SDK skills

> **Private beta.** Use of these skills is subject to Iterable's
> [Beta Terms](https://iterable.com/legal/beta-terms/). This documentation is
> confidential, may contain inaccuracies, and may change during the beta.

Use these skills with Claude Code, Cursor, or Codex to integrate Iterable's
Android or React Native SDK. For Android push integrations, the workflow can
also create the required Firebase resources and verify that a real push
notification reaches your device.

The plugin runs under your coding assistant. The provisioning workflow asks
before reading or changing scoped cloud resources.

## Included skills

| Skill | Purpose |
|---|---|
| `iterable-provision` | Creates and verifies Firebase prerequisites, then guides and checks the required Iterable setup. |
| `iterable-android` | Integrates and troubleshoots Iterable's native Android SDK using version-pinned documentation. |
| `iterable-react-native` | Integrates and troubleshoots `@iterable/react-native-sdk`, including Expo projects. |
| `iterable-verify` | Verifies an Android push integration by confirming that a real notification reached a selected device. |

The skills can work independently. For a new Android push integration, the
usual sequence is:

`iterable-provision` → `iterable-android` or `iterable-react-native` → `iterable-verify`

Skills are model-invoked. Describe the outcome you want rather than running a
skill by name. For example:

- "Set up Iterable push notifications in this app."
- "Integrate Iterable's React Native SDK."
- "Why isn't my push notification arriving?"
- "Verify that this integration works on my emulator."

## Supported workflows

- Native Android SDK integration.
- React Native integration for Android and iOS, including Expo.
- Firebase provisioning and device-side push verification for Android.
- Push notifications, in-app messages, mobile inbox, embedded messaging, deep
  links, JWT authentication, event tracking, and user profiles.
- Unknown user activation for native Android.

Native iOS and web skills are not included. Provisioning and device-side proof
are Android-first; the React Native skill can integrate the iOS SDK, but it does
not provision or verify APNs.

## Requirements

### Accounts

- An Iterable project. The provisioning skill can guide you through creating
  the required Iterable API keys and mobile configuration.
- A Google account with access to a Firebase project, or permission to create
  one, when setting up Android push.

You authenticate with Google and Iterable yourself. The plugin does not ask for
or handle your account passwords.

### Command-line tools

The provisioning and verification workflows require these non-standard tools:

```bash
node --version
gcloud --version
adb --version
```

| Tool | Used for | Installation |
|---|---|---|
| `gcloud` | Google authentication, Firebase projects, service accounts, IAM, and key creation | [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) or `brew install --cask gcloud-cli` |
| `adb` | Selecting an Android device and reading the installed app, SDK registration, and arriving notification | Android Studio's SDK Manager or `brew install --cask android-platform-tools` |
| Node.js | Parsing command and API output | [nodejs.org](https://nodejs.org) or `brew install node` |

The scripts also use Bash, `curl`, and standard Unix utilities. They do not
install or modify your JDK, Gradle, Android SDK, or Node.js toolchain. During
integration, your coding assistant may run your project's existing build and
install commands with your approval.

If a required tool is missing, the workflow reports which tool is needed and
stops without attempting to install it.

### Android device

Device-side verification requires a connected Android device or a running
emulator with Google Play services. You select the target device, even when
only one is connected, so the proof is performed on the device you intend to
test.

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
for skill in iterable-provision iterable-android iterable-react-native iterable-verify; do
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
- The verification gates only read application and notification state. A
  separate actor can open the selected app's launcher activity, but it does not
  tap, type, sign in, or answer permission prompts.

Your coding assistant runs with your local privileges. Its handling of source
code and conversation data is governed by the assistant provider and your
organization's configuration. Install plugins only from sources you trust.

## Current limitations

- Firebase provisioning and device-side proof support Android only.
- Creating Iterable API keys, mobile apps, and push integrations requires
  dashboard interaction because these actions do not have public APIs.
- JWT-enabled mobile API keys are recognized but are not currently supported by
  the verification workflow.
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
