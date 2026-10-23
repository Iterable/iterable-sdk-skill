# Iterable SDK skills

> **Private beta.** Use of these skills is subject to Iterable's
> [Beta Terms](https://iterable.com/legal/beta-terms/). This documentation may
> contain inaccuracies and may change during the beta.

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

For a React Native app with both platforms in scope, the workflow finishes
Android first, including a proved push, and then sets up iOS. The iOS setup
reuses the Iterable keys, region, and feature scope from the Android setup.

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
- Apple/APNs prerequisite guidance and iOS push proof on the iOS Simulator.
- Push notifications, in-app messages, mobile inbox, embedded messaging, deep
  links, JWT authentication, event tracking, and user profiles.
- Unknown user activation for native Android and native iOS.

Web SDK integration is not included.

## Requirements

### Accounts

- An Iterable project, and an Iterable role that can create API keys and
  mobile apps. The provisioning skill can guide you through creating the
  required Iterable API keys and mobile configuration.
- A Google account with access to a Firebase project, or permission to create
  one, when setting up Android push. The account must be able to enable APIs,
  add Firebase, and create a service account and its key.
- Apple Developer Program access to the app's team when setting up native iOS
  push. Registering the App ID, enabling Push Notifications, and creating an
  APNs key require the **Account Holder** or **Admin** role. The workflow
  cannot replace Apple sign-in, 2FA, agreements, or the one-time download of a
  newly created APNs private key.

You authenticate with Google, Apple, and Iterable yourself. The plugin does not
ask for or handle your account passwords.

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
| Xcode 14 or later | Building, signing, installing, and observing native iOS apps | Install the full Xcode app, not only the Command Line Tools, then select it with `xcode-select` |
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
Simulator or a signed physical iPhone. A Simulator receives real APNs sandbox
pushes only on macOS 13 or later with Xcode 14 or later, on a Mac with Apple
silicon or a T2 chip. Production/TestFlight proof requires a physical iPhone.

React Native and Expo apps are proved on iOS with a Release build, which embeds
the JavaScript bundle and runs without Metro. Expo apps need a development
build (`expo-dev-client`); Expo Go cannot load the SDK's native module.

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

Run `/reload-plugins`, or start a new Claude Code session, to load the skills.

To receive updates automatically, open `/plugin`, select **Marketplaces**,
select **iterable**, and select **Enable auto-update**.

### Cursor

Cursor installs plugins from a marketplace, so you first add this repository
as a marketplace and then install the plugin from it. Before you start, sign
in to Cursor and update it to the latest version. <!-- verify in UI -->

1. Open **Customize** in the sidebar, then open **Plugins**.
2. Select **+ Add**, then **From GitHub Repository**.
3. In **Import Marketplace**, enter
   `https://github.com/Iterable/iterable-sdk-skill` under **Repository**. Leave
   **Scope** set to **User**, then select **Import**.
4. Cursor switches to the marketplace browser. Select **Personal** or
   **Iterable**, whichever the marketplace is listed under, to see its plugins.
   Then open **iterable-sdk**.
5. On the plugin's page, select **Install**. If Cursor asks for a scope, choose
   the project or user scope.

The plugin installs the skills, the scripts they run, and the Context7 MCP
server. To confirm the install, open **Customize** and check that:

- **Plugins** lists **iterable-sdk**.
- **Skills** lists the six `iterable-*` skills.
- **MCPs** lists `context7`.

Then start a new Agent chat.

If **From GitHub Repository** is missing, open the marketplace from
**Customize**, select **Add Marketplace**, then **Import from GitHub**. <!-- verify in UI -->

Who can import depends on your plan:

- **Free and Pro:** follow the steps above.
- **Teams:** the steps above work, because community plugin import is on by
  default.
- **Enterprise:** community plugin import is off by default. Ask an admin to
  allow it, or to add the repository as a team marketplace. <!-- verify in UI -->

If your organization blocks the Context7 MCP server, the plugin still installs,
but its documentation lookups can't run.

If you installed the plugin in Claude Code, Cursor also loads that copy while
**Include Third-Party Plugins, Skills, and Other Configs** is on, in
**Cursor Settings → Agents → Third-Party Imports**. That copy updates through
Claude Code. <!-- verify in UI -->

#### Team marketplace

On Teams and Enterprise, an admin can share the plugin with the whole team:

1. Go to **Dashboard → Plugins & MCPs**.
2. In **Team Marketplaces**, click **Add Marketplace**, choose
   **Import from Repo**, and paste the repository URL.
3. Add **iterable-sdk** with **Add to Marketplace**.
4. Under **Marketplace Settings**, set **Marketplace Access**, then save.
5. Choose how the plugin is distributed: **Default Off**, **Default On**, or
   **Required**.

Teammates then find the plugin in **Customize**. The Teams plan allows one
imported team marketplace. Auto Refresh needs the Cursor GitHub App on the
repository, so select **Refresh** to pick up a new version.

#### Local checkout

To test a local checkout, clone it into Cursor's local plugin folder:

```bash
git clone https://github.com/Iterable/iterable-sdk-skill.git ~/.cursor/plugins/local/iterable-sdk
```

Run **Developer: Reload Window**, then confirm the skills in **Customize**.
Cursor skips a symlink in that folder that points to a clone elsewhere. If
**iterable-sdk** is also installed from a marketplace, that install takes
precedence over the local copy. On Enterprise, an admin must turn on
**Allow Local Plugin Imports**.

#### Fallback: link the skill directories

If you can't install plugins, clone the repository and link the skill
directories. This installs the skills without the Context7 MCP server:

```bash
git clone --depth 1 https://github.com/Iterable/iterable-sdk-skill.git ~/iterable-skills
mkdir -p ~/.cursor/skills
for skill in iterable-provision iterable-android iterable-android-verify iterable-ios iterable-ios-verify iterable-react-native; do
  ln -sfn ~/iterable-skills/$skill ~/.cursor/skills/$skill
done
```

Keep the clone in place, because the skills run scripts from it. Run
**Developer: Reload Window**, then start a new Agent chat.

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

1. The integration skill inspects the application and agrees the integration
   scope with you.
2. If Firebase or Iterable prerequisites are missing, the provisioning skill
   explains what it needs to read and asks for permission before continuing.
3. The workflow creates or selects the Firebase resources and service account.
4. It guides you through the Iterable dashboard actions that do not have a
   public API: API keys, the mobile app, the Firebase push integration (with
   FCM type **Data notifications**), and the test user's email address or
   user ID, whichever the app identifies users by.
5. The integration skill adds the SDK configuration, and your coding assistant
   builds and installs the application using the project's existing toolchain.
6. The workflow opens the selected application's launcher activity. You sign in
   as the test user and respond to any Android permission prompts.
7. The verification skill sends a proof notification and checks Android's
   notification service to confirm that it arrived.

The component that performs an action does not verify its own result. For
example, the sender records which proof notification it sent, while a separate
read-only verifier checks the device for that notification.

## What happens during iOS push setup

1. The integration skill inspects the application and agrees the scope and the
   user identity with you, once. Provisioning reuses these answers.
2. If Apple prerequisites are missing, the provisioning skill guides you through
   Apple Developer one step at a time: the App ID, Push Notifications, and the
   APNs key. It checks the APNs key with one sandbox probe.
3. It guides you through the Iterable Mobile and Server-side API keys and the
   iOS app with its APNs credential, and checks the keys with live calls.
4. The integration skill writes the SDK code. Your coding assistant builds the
   app and installs it on the Simulator.
5. You sign in to the app and allow notifications.
6. The verification skill confirms that Iterable holds the Simulator's device
   token, sends one marked proof notification, and reads its arrival from the
   Simulator's own notification records.

If the app already sends its own push notifications, the integration skill asks
whether to keep them alongside Iterable's or use Iterable notifications only.
Iterable's proof completes the integration; checking the app's own
notifications afterwards is optional.

## Security and data handling

- The repository's scripts run locally and make authenticated HTTPS requests
  to Google, Firebase, Apple, and Iterable.
- Push proof creates or updates one proof template in your Iterable project and
  sends it only to the test user. The test identity becomes a real user profile
  in that project.
- The plugin also adds the Context7 MCP server (no API key) for documentation
  lookups and, in Claude Code, five helper subagents.
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
- Android push proof needs a Mobile API key with **Require JWT** turned off. On
  iOS, core verification can run for a JWT-enabled integration, but the app's
  JWT backend behavior requires separate feature-specific evidence.
- Some bundled source articles cover multiple mobile platforms and may include
  snippets that are not relevant to the current application.
- These skills focus on SDK integration. To work with campaign or user data,
  use Nova Agent in Iterable or
  [Iterable's MCP Server](https://support.iterable.com/hc/articles/42936800222612).

## Updating

For Claude Code, update the marketplace before updating the plugin. Run these
commands in a terminal:

```bash
claude plugin marketplace update iterable
claude plugin update iterable-sdk@iterable
```

Then run `/reload-plugins`, or start a new session. With auto-update enabled,
Claude Code may ask you to reload plugins after a newer version is downloaded.

For Codex:

```bash
codex plugin marketplace upgrade iterable
```

Then start a new Codex session.

For Cursor, the plugin is indexed when you import the repository. To get a
newer version, refresh the marketplace from **Customize**, or remove it and
import it again. <!-- verify in UI --> For a team marketplace, an admin
selects **Refresh** in **Dashboard → Plugins & MCPs**. For a local plugin
checkout, run `git pull` in `~/.cursor/plugins/local/iterable-sdk` and reload
the window. For the clone-and-link fallback:

```bash
cd ~/iterable-skills
git pull
```

Then run the link loop again so that new skills are linked, reload the Cursor
window, and start a new Agent chat.

## Uninstalling

```bash
# Claude Code (add --scope project or --scope local if you installed there)
claude plugin uninstall iterable-sdk@iterable
claude plugin marketplace remove iterable

# Codex
codex plugin remove iterable-sdk@iterable
codex plugin marketplace remove iterable
```

For Cursor, open **iterable-sdk** in **Customize** and select **Uninstall**.
You can then remove the marketplace. That removes it from your Cursor account
and leaves the repository unchanged. <!-- verify in UI --> For a local
checkout, delete `~/.cursor/plugins/local/iterable-sdk`. For the
clone-and-link fallback, delete the links in `~/.cursor/skills/` and the
`~/iterable-skills` clone.

Uninstalling the plugin leaves cloud resources in place. Before you uninstall,
run `.iterable/teardown` from your project to remove the Google service account,
its role binding and keys, and the local artifacts that Android setup created.
Apple resources and your APNs key are not removed.

## Contributing and architecture

Repository-maintenance commands are documented in
[`CONTRIBUTING.md`](CONTRIBUTING.md). In particular, Docs team members can use
the copy-review workflow there to render onboarding questions without
credentials, network access, or a connected device.

Engineering references:

- [`bin/README.md`](bin/README.md) — onboarding program architecture.
- [`INTENDED-FLOW.md`](INTENDED-FLOW.md) — authoritative onboarding sequence.
- [`REVIEW.md`](REVIEW.md) — how to review refreshed SDK reference docs.
