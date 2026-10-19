# Opening

## Header

Setup

## Prompt

Do you want to proceed with setup?

## Context

This setup creates the `google-services.json` file and the Iterable mobile app,
push integration, and API keys your app needs. It doesn't start until you choose
to continue.

{{part_map}}

How it works:

- The skill reads your Firebase projects, the Android apps in each project, your app's
build files, and a connected device or emulator. It uses the Google account
already signed in to gcloud.

- It doesn't change your Google project yet. Before any change, you'll see each
change listed by name. You can decline, and setup stops.

- It doesn't ask for your password, accept an API key in this conversation, or
write a placeholder `google-services.json` file so the build can succeed. If a
required file or value is missing, setup stops and names what's missing.

- Iterable has no API to create an API key, a mobile app, or a push integration, so
the skill helps you complete these tasks in Iterable and checks the result of each step.

## Requirements

Sign in to Google yourself. If you haven't run `gcloud auth login` in your
terminal yet, do so now. Setup never sees your password.

## Option: agent

### Label

Yes — set it up in this chat

### Description

Each step appears as a question in this conversation, using the same steps as
terminal setup. Nothing changes until you confirm that step. Copy the two
Iterable API keys from your clipboard into a private file on your machine
(mode `0600`). The keys never appear in this conversation.

## Option: terminal

### Label

Run setup in your own terminal

### Description

You complete the same work and answer the same questions in a terminal menu.
Google sign-in stays in that terminal session, and you answer each prompt with
the arrow keys. Choose this option to keep these choices out of a chat.

## Option: stop

### Label

No — stop here

### Description

Nothing runs, and nothing is read or written. Setup doesn't create a workspace
directory in your repository.
