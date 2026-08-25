# OnePlus One — SFTP storage donor for Nextcloud

Follow-up to `docs/experiments/oneplus6t-vpn-server-nextcloud.md`'s "External storage
backend decision for donor devices" section, which decided on SFTP over FTP/WebDAV but
explicitly left per-device onboarding as "not yet done." This is that write-up for the
first donor device.

Plan this executes: `.claude/plans/lets-discuss-about-immich-floofy-valley.md`
("Storage-donor SFTP setup — old OnePlus device").

## Device

- **OnePlus One** (codename `bacon`, model A0001), Android **5.1.1**, API level **22**.
- **Not rooted** — contrary to initial assumption going into this session
  (`su: not found`). Proceeded without rooting per user decision — Primitive FTPd/SFTP
  serving doesn't strictly require root, just some of the more robust always-on tricks
  used on the 6T aren't available here.
- CPU: `armeabi-v7a` (Snapdragon 801 / Krait 400 — 32-bit only, predates ARMv8).
- Has TWRP recovery installed (leftover from prior CyanogenMod experimentation,
  confirmed by the user) — not used this session, noted only as a future option if
  rooting is ever revisited.

## Storage cleanup

Found and removed `/sdcard/oem_log` — thousands of `OPBR_<timestamp>.zip` files
(OnePlus auto-generated bug-report archives, 2019–2022), 12GB, confirmed via `du -sh`
before deleting. Purely disposable, no root needed (`/sdcard` is writable by the plain
`shell` user via the `sdcard_rw` group). Freed the device from 33.6GB to **50.1GB**
free.

## Primitive FTPd: two separate real failures, then abandoned

The originally-planned app (per the earlier SFTP-vs-FTP decision). Investigated its
actual minSdk history via GitHub tags' `build.gradle` (not assumed) since the *current*
release requires Android 8.0+:

- **Version 7.5** (Dec 2025) was the last release with `minSdkVersion 15` — installed
  this first. **Crashed** on launch:
  `androidx.fragment.app.Fragment$InstantiationException: Unable to instantiate
  fragment org.primftpd.ui.PubKeyAuthKeysFragment: could not find Fragment constructor`
  — a real compatibility bug between this release's AndroidX Fragment library version
  and this device's runtime, not a config mistake. The background service actually did
  try to restart independently of the crashing UI, but never got to bind a socket.
- **Version 6.16** (last of the 6.x series, also `minSdkVersion 15`) — installed
  cleanly, launched without crashing (older, simpler non-tabbed UI,
  `PrimitiveFtpdActivity` not `MainTabsActivity`, avoiding the specific Fragment that
  crashed 7.5). But **the UI was completely unresponsive** — confirmed via screenshot
  that it rendered correctly (IP, ports, storage-type radio buttons all visible and
  correct), but neither a `input tap` at the exact correct coordinates (verified against
  real screen resolution and confirmed window focus) nor the hardware Menu key
  (`keyevent 82`, in case this UI predates the on-screen overflow-menu convention)
  produced any response. Two different real bugs in two different versions — concluded
  this is a genuine compatibility problem with this specific device/ROM, not a
  version-picking mistake, and not worth continuing to trial-and-error through more
  releases.
- **Uninstalled entirely** (`adb uninstall org.primftpd`) once Termux was working.

## Pivot: Termux + real OpenSSH

Different architecture entirely — a real terminal instead of a custom Android settings
UI, sidestepping the exact class of bug just hit.

- Termux's *current* releases require API 24+, same problem as Primitive FTPd — but
  Termux ships a dedicated **legacy bootstrap variant** for old devices
  (`apt-android-5`, `minSdk 21`), confirmed via `build.gradle`'s
  `bootstrapMinSdk = packageVariant == "apt-android-5" ? 21 : 24`. Used
  `termux-app_v0.119.0-beta.3+apt-android-5-github-debug_armeabi-v7a.apk` (architecture
  matched to the device, not assumed — confirmed via `getprop ro.product.cpu.abi`
  first). No equivalent legacy variant exists for **Termux:API** (checked every release
  back to 2020 — all require API 24+), so that companion app is a dead end on this
  device (relevant later, see Battery logging below).
- First-run bootstrap install completed normally; the app explicitly self-identifies:
  *"You are using legacy Termux environment. Packages are unmaintained and will not
  receive any updates"* — confirms the right variant was picked.
- `pkg install openssh` — succeeded, auto-generated ED25519/ECDSA host keys.
- Set a login password via `passwd` (value not recorded here, same no-credentials-in-repo
  convention as the Nextcloud admin/DB passwords earlier), started `sshd` (listens on
  **port 8022** — Termux's standard unprivileged-port convention), username is
  **`u0_a118`** (Termux's own Android-UID-derived username, confirmed via `whoami`).
- Verified real TCP reachability from the 6T (`/dev/tcp` test) before configuring
  anything Nextcloud-side — ruled out AP/client isolation on the router as a risk
  (genuinely untested until this point, since every prior LAN interaction had been
  phone-to-router or via Tailscale, never phone-to-phone directly).

### Real `adb` interaction quirks hit along the way (worth keeping for next time)

- `adb shell input text` needs literal spaces encoded as `%s` — well-known, but also:
  **a trailing `&` character silently breaks the entire injected string** on this old
  Android's `input` implementation (confirmed by isolating — the same string without
  `&` typed fine). Workaround used: avoid needing to background commands via `&` in
  injected text at all; either run them via a separate Ctrl+C-interruptible foreground
  session, or invoke commands through other means.
- The device's **screen timeout repeatedly interrupted work** — commands sent while the
  screen was asleep/locked silently went nowhere (target app loses window focus, e.g.
  focus was found sitting on an unrelated `SwiftKeyPreferencesActivity` at one point).
  Fixed by extending `screen_off_timeout` via `settings put system screen_off_timeout
  1800000` for the duration of interactive setup, and always re-checking
  `dumpsys window windows | grep mCurrentFocus` after any gap before sending more input.
- **`adb shell` (uid `shell`) cannot execute anything inside another app's private data
  directory** (`/data/data/com.termux/...`) without root — confirmed directly
  (`bash: ... not found`, not a permission-denied message, consistent with a
  stat()-level directory-traversal block). This means Termux's own shell can only be
  driven through its on-screen terminal (simulated taps/keystrokes), not shelled into
  directly via `adb shell` — a real, structural limitation on a non-rooted device, not
  a one-off bug.
- **Regular apps cannot call `dumpsys <service>` at all** — confirmed directly inside
  Termux: `/system/bin/dumpsys battery` → `Error dumping service info: (Unknown error
  -2147483646) battery`. This is a Binder/permission restriction specific to unprivileged
  app processes (`adb shell`, by contrast, has broad diagnostic access and this same
  command works fine from there) — directly explains why Termux:API existing (and being
  installable) would have mattered: it gets battery data through the proper
  `BatteryManager` app-facing API instead of `dumpsys`, which regular apps *are*
  allowed to call. Since Termux:API can't be installed here at all (see above), this
  path is closed on this device specifically.
- Sending Ctrl+C into the terminal: no dedicated keycode for the combo: tap the
  on-screen **CTRL** toggle key first, then send the literal character (`c`) via
  `input text` — worked reliably to interrupt a stuck foreground process.

## Nextcloud mount

Created directly on the 6T via `occ files_external:create` (server-side CLI — see
the credentials note under "Nextcloud trash bin" below for why this needed no
Nextcloud login at all):

```
occ files_external:create 'OnePlus One Storage' sftp password::password \
  --config host=192.168.88.9 --config port=8022 \
  --config user=u0_a118 --config password=<redacted> \
  --config root=/storage/emulated/0
```

- Created as mount id 2, a system mount (no `--applicable-user`/`--applicable-group`,
  so visible to all users, not scoped to just admin).
- Verified two ways: `occ files_external:verify 2` → `{"status":"ok"}`, and
  `occ files:scan` on the mount, which found **136 folders, 1136 files** — real content
  already on the donor phone, genuine end-to-end proof, not just a connectivity check.
- A **stale duplicate mount (id 1, `/OnePlusOne`, pointing at the abandoned prim-ftpd
  port 1234 with different credentials)** was found during this — apparently created by
  the user directly through the Nextcloud web UI while the prim-ftpd debugging was
  still in progress, pointing at a server that no longer exists. Removed by the user
  once flagged.

## Battery-drain logging

The actual motivating question behind bringing this device online at all: how long does
an old, non-rooted Android phone last running an SFTP server, and does Android kill it
in the background before the battery does?

- **Termux:API is not usable on this device** (see above) — the clean, correct way to
  read battery stats from inside an app doesn't exist here as an installable option.
- **Adopted instead**: external polling — `adb shell dumpsys battery` (works fine from
  `adb shell`, just not from inside an app process) run periodically from outside,
  appending results to `/sdcard/battery_log.txt` **on the device itself**, so the data
  persists regardless of whether any particular session stays connected.
- **Wireless `adb` enabled** (legacy `adb tcpip 5555` method — this device predates the
  Android 11 Wireless Debugging toggle used on the 6T) so the device doesn't need to
  stay USB-tethered for future polling.
- **Explicit decision, not an oversight**: the user declined to set up recurring
  `/loop`-based automated polling for this ("would unnecessarily use up tokens") —
  logging happens on-demand when asked, not on an automated cadence. Worth respecting
  this if picking the experiment back up later rather than assuming continuous
  monitoring is wanted.
- **Auto-start is NOT configured** for anything in this new setup. The "start on boot"
  toggle set earlier in Primitive FTPd's settings is irrelevant now — that app was
  completely uninstalled. Termux/`sshd` currently only run because they were started
  manually this session; neither survives a reboot, and there's no `Termux:Boot`
  installed (a companion app that would provide this, analogous to the 6T's
  `BOOT_COMPLETED`-receiver-based Pi Deploy auto-start) — a real, currently-open gap,
  distinct from the background-kill question the battery logging is actually measuring.

## Nextcloud trash bin — quota lesson (not specific to this device, but surfaced here)

A large (~6.8GB) test file (a 4K `.mkv`) was uploaded to test the new mount, then
deleted — but reported storage usage didn't drop. Root cause, confirmed by direct
filesystem inspection rather than assumption: Nextcloud's **trash bin** ("Deleted
files") retains deleted files (30-day default retention) and they continue occupying
real disk space until the trash is emptied — this is standard, expected Nextcloud
behavior, not a bug. Found via `du -sh` on `admin/files_trashbin` (6.9GB) vs. the
near-empty real `admin/files` (63MB); `occ user:info admin`'s own reported "used" figure
was stale/did not reflect this, so the filesystem-level check was the one that actually
answered the question. User emptied the trash directly.

Separately clarified during this: `occ files_external:create` and other `occ` commands
run as a **server-side CLI operation** (via SSH, as the `www-data` system user) — they
never go through Nextcloud's web login at all, so they're unaffected by a Nextcloud
account password ever being changed. A one-off `curl` WebDAV test using a by-then-stale
admin password failed authentication as a direct, correct consequence of the password
having been changed — not a bug or a security concern, just a stale credential in an
ad hoc diagnostic command.

## Status at time of writing

- SFTP donor mount: **working and verified**, real content scanned successfully.
- Battery-drain data collection: **infrastructure ready** (on-device log file, wireless
  adb reachable), no recurring automated polling running per explicit user preference —
  data collection happens on request.
- Boot persistence: **not configured**, open item, lower priority than the
  background-kill question currently being observed.
- Stale duplicate mount: removed.
- Trash bin space: reclaimed.
