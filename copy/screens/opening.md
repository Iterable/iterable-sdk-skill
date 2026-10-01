# Opening

## Header

Setup

## Prompt

Do you wish to proceed?

## Context

You need a google-services.json and the Iterable side set up. Neither can be invented, so
this is the part that produces them — and none of it starts until you say so.

{{part_map}}

What it reads: your Firebase projects and the Android apps in each, your app's build files,
and a connected device or emulator. Reading happens with the gcloud account you are already
signed in as.

What it changes in your Google project: nothing yet. When it gets there you are asked again,
on a screen that lists every change by name, and no is a complete answer to it.

What it never does: ask for a password, take an API key through this conversation, or write
a placeholder google-services.json to make a build go green. If something is missing it
says so and stops.

Part 2 is yours because Iterable has no API for it — no endpoint creates an API key, a
mobile app, or a push integration. I walk you through those four steps and check what each
one produced.

## Requirements

You sign in to Google yourself. If 'gcloud auth login' has not been run in your terminal,
that is the first thing you do, and neither this tool nor the agent ever sees your password.

## Option: agent

### Label

Yes — set it up with me here

### Description

I conduct the whole thing here: every screen the terminal wizard shows, as a question in
this conversation. Nothing changes without its own yes first, and the two Iterable API keys
go from your clipboard into a 0600 file without passing through this conversation — I never
see one.

## Option: terminal

### Label

I'd rather run the whole setup in my own terminal

### Description

Fallback, and a real one: the same work and the same questions as a terminal menu, with the
Google sign-in hosted in the same session and every prompt answered by arrow keys instead of
by relaying. Worth it if you would rather these choices were not in a chat at all.

## Option: stop

### Label

No — stop here

### Description

Nothing runs, nothing is read, and nothing is written — not even a workspace directory in
your repository.
