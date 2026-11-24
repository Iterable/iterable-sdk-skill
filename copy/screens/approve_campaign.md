# Approve campaign

## Header

Campaign

## Prompt

To confirm the push from Iterable's side, the skill creates a push template and
a triggered campaign in your Iterable project, activates the campaign, and sends
one push through it to your test user, {{identity}}. Nothing is created until
you choose yes.

Create the campaign and send the push?

## Context

The proof push doesn't go through a campaign, so Iterable records no send event
for it. The device shows that the push arrived, but Iterable's own record can't
confirm it. A push sent through a campaign is recorded.

What it would do in your Iterable project:

- Create a push template named "Iterable onboard campaign proof". Iterable copies
it into the campaign.

- Create a triggered campaign with the same name, and activate it.

- Send one push through the campaign to your test user, {{identity}}.

After the send:

- The campaign stays active, because archiving an active campaign cancels pushes
it hasn't delivered yet.

- The next campaign send archives it and creates a new one. To reuse it instead,
run the send with `--keep-campaign`.

If your project has only a marketing push message type, the skill stops before
it creates anything. Frequency caps, quiet hours and opt-outs apply to a marketing
push, and any of them can skip the proof push. To continue, add a transactional
push message type in Iterable, or send through the marketing one.

If your project doesn't let the API activate triggered campaigns, the skill stops
after it creates the campaign and sends nothing. Activate the campaign in the
Iterable dashboard, using the link the skill gives you, and the next send uses it.

Your approval covers the Iterable project that your server-side API key belongs
to. A different key needs a new approval.

## Requirements

Nothing to do yourself. The skill uses the server-side API key you added
earlier.

## Option: approve

### Label

Yes — create the campaign and send the push

### Description

Records your approval for this server-side API key's project, then creates the
template and campaign and sends one push to {{identity}}.

## Option: decline

### Label

No — don't create a campaign

### Description

Nothing is created in Iterable and nothing is sent. Iterable's send record stays
unverified, and only the device check confirms the push.
