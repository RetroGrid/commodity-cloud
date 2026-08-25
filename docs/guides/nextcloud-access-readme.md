# Accessing the shared Nextcloud storage

This guide is for someone who's been invited to access storage on Satya's
self-hosted Nextcloud. It only works if you've been invited — there are two separate
things you need before you can get in, and both come from the owner (Satya), not from
this guide:

1. A **Tailscale share invite** (an email/link) — this is what lets your device even
   reach the server at all.
2. A **Nextcloud username and password** — this is your actual login once you can
   reach it.

Neither one alone is enough. You need both.

## Step 1: Install Tailscale

Tailscale is a private networking app — it's what makes the server reachable to you
specifically, without it being open to the internet at large.

- **iOS**: search "Tailscale" in the App Store.
- **Android**: search "Tailscale" in the Play Store.

Install it, but **don't log in yet** — wait for the invite link in Step 2, and log in
using the identity (email) that the invite was sent to.

## Step 2: Accept the share invite

Satya will send you a link (usually by email) that shares access to one specific
device on his network — not his whole network, just that one device.

1. Open the link he sends you.
2. It'll ask you to log into Tailscale (or continue if you're already logged in) —
   make sure you use the same email the invite was sent to.
3. Accept the share.

## Step 3: Confirm you're connected

Open the Tailscale app and check that it shows **"Connected."**

Note: "Connected" here just means the Tailscale app itself is working — it does
**not** by itself prove you can reach the server. If you skipped Step 2 (the actual
share invite) and just logged into your own separate Tailscale account instead, the
app will still say "Connected" but you won't be able to reach anything. If Step 4
doesn't work, this is the first thing to double check with Satya — ask him to confirm
your device shows up under the shared device's "Shared with" list in his Tailscale
admin console.

## Step 4: Open Nextcloud

You can use either a browser or the Nextcloud app (search "Nextcloud" in your app
store) — same login either way.

**Server address:**
```
http://100.80.112.70:54280
```

**Important:** type it exactly like that, including the `http://` at the start. If
your app defaults to `https://` (secure) instead, or you leave the `http://` off and
it fills it in automatically, the connection will fail with a certificate/TLS error.
This server intentionally uses plain `http://` — the connection is already encrypted
by Tailscale itself, so this is expected and fine, not a mistake.

**Username and password:** ask Satya for these separately — they're not in this
guide.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Tailscale says "Connected" but the Nextcloud address won't load at all | You're on your own separate Tailscale account, not actually sharing this device | Ask Satya to confirm your device is listed under the device's "Shared with" list; you may need to redo Step 2 |
| "TLS error" or certificate warning when opening Nextcloud | The app tried `https://` instead of `http://` | Re-enter the address with `http://` explicitly typed at the start |
| Login works but you don't see any files | Wrong account, or your account has no files shared to it yet | Ask Satya to check your Nextcloud account/permissions |

## A note on why this exists

This setup deliberately requires two separate approvals (a Tailscale share **and** a
Nextcloud account) rather than a single public link — it means the storage is never
exposed to the open internet, and access can be revoked at either layer independently
if it's ever needed.
