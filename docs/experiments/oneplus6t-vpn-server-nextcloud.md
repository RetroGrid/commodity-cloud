# OnePlus 6T — WireGuard server + Nextcloud (extending the Pi Deploy chroot)

Follow-up to `docs/experiments/rooted-oneplus6t-vpngateway.md`. That experiment built an
*outbound* WireGuard client (interface `proton`) so LAN devices could route through
ProtonVPN. This one adds the reverse: an *inbound* WireGuard server (interface `wg0`) so
remote devices can reach services running on the phone itself (Nextcloud, Pi-hole) from
outside the home network — plus Nextcloud itself, installed in the same chroot.

Plan this executes: `.claude/plans/lets-discuss-about-immich-floofy-valley.md`.

Scope deliberately kept narrow: remote peers can only reach services running *on* the
phone, not the rest of the home LAN. This was a conscious choice (confirmed with the
user) specifically to avoid re-doing the `netd`/`tetherctrl_FORWARD` authorization dance
that consumed most of the effort in the original gateway experiment — that wall only
applies to traffic *forwarded through* the phone to other devices, not traffic that
terminates at the phone's own sockets.

## Prerequisite closed: what "Pi Deploy" actually is

Previously undocumented gap (flagged in the earlier doc's research). Confirmed by
inspecting the running chroot directly:

- Init mechanism is a plain `/etc/init.d/android-raspbian` SysV script (with a companion
  `android-raspbian-status`) — this is the actual boot/start mechanism behind the "Pi
  Deploy" name used casually elsewhere in this repo.
- `PID 1` inside the chroot is plain `init`, not systemd. `systemctl` is installed
  (`systemd 219`) but inert — `systemctl list-units --type=service --state=running`
  reports 0 loaded units. So it's a real SysV-init environment, not a systemd one:
  any new persistent service needs an `/etc/init.d/` script, matching how `sshd` and
  `pihole-FTL` already run, not a systemd unit file.
- **Boot persistence, previously unknown, now confirmed**: the Android-side app behind
  "Pi Deploy" is `com.desktopecho.pideploy` (built on "Raspbian for Android" — the base
  image is in fact a DesktopECHO/NextCloudPi-flavored image, evidenced by an
  `/etc/hosts` alias to `nextcloudpi` and `unbound`/`xrdp`/`prometheus` already present
  in the user-group setup in `android-raspbian`, unrelated to this session's own
  Nextcloud install). It registers a real `BootReceiver` for
  `android.intent.action.BOOT_COMPLETED` (and `ACTION_SHUTDOWN`) — confirmed via
  `dumpsys package com.desktopecho.pideploy`. So the chroot genuinely auto-starts on
  phone reboot; this was previously an open question in this doc and the original
  gateway experiment. Anything registered via this chroot's own SysV runlevels
  (`sshd`, `pihole-FTL`, and — added this session — `apache2`, `mariadb`, `tailscaled`)
  should therefore come back automatically after a reboot. The original hand-rolled
  `wg0` WireGuard server and its custom `ip rule`/`ip route` additions are the
  exception — never wired into any startup mechanism, so those specifically still need
  manual reapplication after a reboot if that path is ever used again instead of
  Tailscale.
- Chroot filesystem is the same `/data` partition as the host Android OS (confirmed:
  `df -h` inside the chroot and via `adb shell` both report the same
  `/dev/block/.../userdata`, 108G total / 13G used / ~95G available at the time of this
  session) — consistent with the "not network-namespaced, shares the real kernel" fact
  already documented, extended here to storage too.
- `sudo` inside the chroot (user `android`) is passwordless.

## Storage budget

Confirmed live: 108G total, 13G used, ~95G available on the shared `/data` partition.
User's decision: cap Nextcloud at **90GB** (not the full ~95GB available), leaving
headroom beyond the originally-discussed 10GB buffer for other work on the phone.

## WireGuard server (`wg0`)

Distinct interface and keypair from the existing outbound `proton` client — same
`wireguard-go` userspace fallback (this kernel predates Linux 5.6, no native WireGuard
module, exactly as documented for `proton`) and the same `Table = off` (this kernel
lacks `xt_addrtype`/`nf_tables`, so `wg-quick`'s automatic policy routing can't run
here either).

```
[Interface]
PrivateKey = <server private key, /etc/wireguard/wg0_private.key>
Address = 10.13.13.1/24
ListenPort = 51820
Table = off
```

Server public key: `tn1l73Fa+g6zhqusDXQ+91/ldGBsLn0+H1GoZCkXtCg=`

Brought up with `wg-quick up wg0` — printed the same "missing kernel module, falling
back to wireguard-go" notice as the `proton` setup, confirming this is expected/normal
on this device, not an error.

First peer (a second Android phone) added live with `wg syncconf` (no restart needed):

```
[Peer]
PublicKey = ZuCnfCuJVaw25eWT6j9CxPKk7f2MQCEbNdLHN/d/z2s=
AllowedIPs = 10.13.13.2/32
```

Client side configured as **split-tunnel** (`AllowedIPs = 10.13.13.1/32` on the client),
deliberately chosen over full-tunnel — full-tunnel would require the phone to also
forward/NAT general internet traffic for the remote peer, which is a materially bigger
ask (same class of `netd` forwarding fight as the original gateway experiment, just for
the `wg0`↔`wlan0` pair instead of `proton`↔`eth0`) and was explicitly deferred as
future work, not built here.

## Bug found and fixed: reply traffic silently routed out `wlan0` instead of `wg0`

**Symptom**: WireGuard handshake succeeded (`wg show wg0` showed a live peer, data
transferred, correct endpoint) — the tunnel itself was healthy — but an HTTP request
from the peer to `10.13.13.1` hung and eventually timed out. `curl` from the phone
itself to its own `10.13.13.1` address worked instantly (HTTP 200), ruling out a
service-level problem.

**Diagnosis** (same diagnostic technique as the original experiment —
`ip route get`, and `conntrack -L`):

- `conntrack -L` showed the incoming SYN arriving correctly
  (`src=10.13.13.2 dst=10.13.13.1 dport=80`) but stuck in `SYN_RECV` — the phone never
  successfully replied.
- `ip route get 10.13.13.2 from 10.13.13.1` — simulating exactly the reply packet the
  phone needs to send back — resolved to `via 192.168.88.1 dev wlan0 table 1030`, not
  `wg0`.
- Root cause: this is a **new instance of the same hidden-network-management-layer
  pattern** documented for IPv6 in the original experiment (Android's ConnectivityService
  installing per-recognized-network `ip rule`s), just found this time on the IPv4 reply
  path. The specific culprit: `22000: from all fwmark 0/0xffff iif lo lookup 1030` — a
  broad Android-installed rule that catches any locally-generated, unmarked packet and
  forces it out over the phone's default active network (WiFi). Since `wg0` isn't a
  network Android's ConnectivityService knows about, reply traffic destined back through
  it gets swept into this rule before ever reaching the `main` table (where the correct
  `10.13.13.0/24 dev wg0` connected route actually lives).

**Fix** — a destination-based `ip rule`, higher priority (lower pref number) than the
Android catch-all, modeled directly on the `to $SUBNET lookup 201` fix from the original
experiment's return-path bug:

```
ip rule add to 10.13.13.0/24 lookup main pref 19500
```

Verified: `ip route get 10.13.13.2 from 10.13.13.1` now correctly resolves
`dev wg0`. Retested from the actual peer device — confirmed working end-to-end.

**Note for the future persistence-scripting follow-up** (tracked as Outstanding in the
original experiment doc, still applies): this rule does not survive reboot any more than
the original experiment's rules did, and should be folded into whatever eventually
scripts boot-time re-application for both experiments.

## Aside: why the test showed an "Apache2 Debian Default Page"

Loading `http://10.13.13.1` over the tunnel returned the stock Apache default page,
which briefly looked like a second/wrong web server was somehow answering. Checked and
ruled out — confirmed `pihole-FTL` is the only process bound to port 80
(`ss -tlnp`), no Apache process was running. Explanation: the `apache2` package happens
to already be installed on this chroot (`dpkg -l` confirms it, unused/leftover from the
base image), which drops its stock `index.html` at `/var/www/html/`. `pihole-FTL`'s own
embedded web server also serves static files from that same `/var/www/html` directory,
and Pi-hole's actual admin UI lives one level down at `/admin` — so the bare root just
serves Apache's leftover file. Confirmed genuinely tunneled correctly either way (full
response headers observed, `Content-Length: 10701`, valid `Etag`, etc.) — not a
misrouted/wrong-server situation, just an unexpectedly generic file being served from
the correct process.

**Practical consequence for Nextcloud**: ports 80 and 443 are both already owned by
`pihole-FTL` — Nextcloud cannot bind either. Decision: run Nextcloud on **port 8080**
instead (see plan Step 7/8 — this pairs with the earlier decision to skip TLS entirely
and rely on WireGuard's own encryption, so a non-standard HTTP port has no real downside
here).

## Nextcloud install

Installed inside the same chroot, reusing the `apache2` package already present but
unused (dpkg showed it installed, nothing running) rather than adding a second web
server. Bound to **port 8080 only** — 80/443 stay exclusively `pihole-FTL`'s, confirmed
untouched throughout.

- **Version installed**: Nextcloud 34.0.3.
- **Data directory**: `/var/www/nextcloud-data`, on the same shared `/data` partition
  used for the storage-budget check earlier in this doc.
- **Quota**: admin user capped at exactly 90GB, matching the plan's decision.
- **Trusted domains**: `localhost`, `10.13.13.1:8080` (WireGuard tunnel address),
  `192.168.88.5:8080` (LAN address) — verified reachable via `status.php` on all three.
- **TLS**: deliberately not configured, per the plan's Step 8 decision — WireGuard
  already encrypts anything that reaches this over the tunnel.
- **Persistence**: `mariadb-server`'s own postinstall script already registered SysV
  rc.d links matching the pattern `pihole-FTL`/`sshd` use in this chroot
  (`S14mariadb`/`K01mariadb`); `apache2` needed `update-rc.d apache2 defaults` run
  explicitly to get the equivalent links. Both now start the same way every other
  service in this chroot does — no systemd involved, consistent with the
  `android-raspbian` SysV-init finding above.
- **Credentials**: generated randomly during install, intentionally **not** recorded in
  this repo (same lesson as the stray ProtonVPN private key caught earlier in the
  original gateway experiment) — stored on-device only, at
  `/root/.nextcloud_admin_pass` and `/root/.nextcloud_db_pass`.

**Deviations from the plan worth keeping as lessons:**

1. `mariadb-server`'s install hit an interactive dpkg conffile prompt — this chroot's
   base image already ships a stub `/etc/init.d/mariadb`, which collided with the
   package's own version. Fixed with `apt-get -o Dpkg::Options::="--force-confnew"`.
2. Apache initially failed to start (`Address already in use`) even after editing
   `ports.conf` to remove port 80 — the file actually used `Listen 0.0.0.0:80` (not the
   bare `Listen 80` form), so the first edit pass missed it.
3. **Quota gotcha, easy to get silently wrong**: `occ user:setting <uid> core quota` and
   `... settings quota` both *appear* to succeed but are not what Nextcloud's storage
   layer actually enforces — `occ user:info` kept reporting unlimited quota (`-3`)
   despite them. The key that's actually read is namespaced under `files`:
   `occ user:setting admin files quota "90 GB"`. Confirmed only by re-checking
   `user:info` afterward, not by the command's own success/failure.
4. **The one that would have been a silent, hard-to-notice failure**: `status.php`
   returned HTTP 200 even before `libapache2-mod-php8.2` was installed — but the
   response body was PHP *source code*, not executed output, because only
   CLI-usable PHP extensions had been installed, not the Apache module. Caught only by
   actually reading the response body rather than trusting the status code. Installing
   the module auto-switched Apache's MPM from `event` to `prefork` (required by
   `mod_php`, expected and fine for a single-device instance like this).

**Verification, all passed** (`installed:true` from `status.php` in every case):
localhost, LAN address (`192.168.88.5:8080`), and the WireGuard tunnel address
(`10.13.13.1:8080`) all independently confirmed reachable.

## `wg0` decommissioned in favor of Tailscale

Once Tailscale was working end-to-end (see below), the hand-rolled `wg0` server was
removed entirely rather than left running unused:

- `wg-quick down wg0`, then deleted `/etc/wireguard/wg0.conf` and its keypair files.
- Removed the `to 10.13.13.0/24 lookup main pref 19500` `ip rule` — meaningless once the
  interface it existed for is gone.
- Removed the now-stale `10.13.13.1:54280` entry from Nextcloud's `trusted_domains`.
- **Deliberately kept**: the `ip route add default via 192.168.88.1 dev wlan0 table main`
  fix from the Tailscale section below — unrelated to `wg0` itself, it's what makes
  Tailscale's own fwmark-based self-traffic exemption work, and Tailscale remains in
  active use.

The pre-existing outbound `proton` client (from the original gateway experiment) was
left untouched — out of scope for this cleanup.

## Pivot to Tailscale (CGNAT defeated the port-forward approach)

The router's own WAN status page showed a private-range address
(`10.45.5.27`, gateway `10.242.0.1`) — not the real public IP (`49.205.200.40`,
independently confirmed from two other devices on the same network) — confirming the
ISP uses CGNAT. This was flagged as a real possibility from the start; the informal
same-public-IP check done earlier (comparing external IP from two LAN devices) could
not have caught it, only logging into the router's actual WAN status page could. The
port-forward rule was removed from the router entirely once this was confirmed —
lesson captured separately as a standing process note (resolve gating/feasibility
unknowns definitively, before building dependent work on top of them, not after hitting
the wall).

**Tailscale install** (in the same chroot):

- Official Debian package repo, `apt install tailscale` — straightforward.
- No `/etc/init.d/` script ships with the package (only systemd units), consistent with
  every other package installed tonight — wrote one (`/etc/init.d/tailscaled`) using
  `start-stop-daemon --background`, registered via `update-rc.d`, matching the pattern
  used for `apache2`/`mariadb`.
- **Bug found**: `tailscale up` produced no output and no error — just hung
  indefinitely with an empty `AuthURL` in `tailscale status --json`. Root cause, found
  by running `tailscaled` in verbose foreground mode: it installs its own self-traffic
  exemption using fwmark `0x80000` (rules at `ip rule` pref 5210/5230/5250) specifically
  so its own control-plane connections route through the OS's normal `main`/`default`
  tables rather than potentially looping through its own future tunnel. But `main` table
  had **no default route at all** on this device — a direct consequence of the
  `Table = off` approach used for both `proton` and `wg0`, since all real routing here
  happens through Android's own per-network tables (1030 for WiFi, etc.), not `main`.
  So tailscaled's marked traffic found nothing in `main`, and fell through to its own
  explicit `unreachable` fallback (pref 5250) — hence silent, total failure to reach
  *any* host, confirmed via tailscaled's own log showing `network is unreachable` for
  every DERP bootstrap and log-upload attempt, both IPv4 and IPv6.
  **Fix**: `ip route add default via 192.168.88.1 dev wlan0 table main` — gives
  tailscaled's self-traffic exemption a real path out. This route is a hard dependency
  for Tailscale on this device and must be kept (see decommission note above).
- Login succeeded immediately once that route existed. Device appears on the tailnet as
  `oneplus6t-nextcloud` at `100.80.112.70`.
- A `tailscale status` health-check warning appeared (`iptables -N ts-input` failing
  with "No chain/target/match by that name") — same error *signature* as the
  `netd`-owned-chain problem from the original gateway experiment, but confirmed
  non-blocking here: verified actual reachability directly with `curl` rather than
  trusting the health check, and it worked (see below).

**Sanity check caught a real bug before declaring success**: `curl` to Nextcloud via
the phone's own Tailscale IP initially returned HTTP 400 with body
`{"error": "Trusted domain error.", "code": 15}` — not a network problem, just
Nextcloud's `trusted_domains` rejecting the unrecognized host. Fixed by adding
`100.80.112.70` (and later, once the port changed, `100.80.112.70:54280`) via
`occ config:system:set trusted_domains`.

**Second device / external user access**: a second Android phone, logged into the
*same* Tailscale account, worked immediately. A third device — a different person,
invited via the Tailscale admin console's **Users panel** — showed as invited but never
appeared in the Machines list and could never reach the server, despite the app itself
reporting "connected" (with its own valid-looking `100.x` tailnet address). Root cause:
on a personal (non-organization-domain) Tailscale plan, the Users-panel invite path is
not the correct mechanism for adding an unrelated outside person — it can leave them in
a state where their own device authenticates to Tailscale's control plane and gets an
address on *some* tailnet, without ever being routed to this one. The correct mechanism
for this case is **sharing the specific machine** (Admin console → Machines → target
device → Share, entering their email), which they must then explicitly accept — this
worked immediately once used instead.

**TLS error on the newly-shared device**: their Nextcloud app failed with a TLS error
even though the underlying Tailscale connectivity was confirmed working. Ruled out
server-side causes directly (`apache2ctl -M` confirmed no `mod_ssl` loaded at all, and
the access log showed zero record of the connection attempt even reaching Apache as an
HTTP request) — consistent with the client defaulting to `https://` against a
plain-HTTP-only port, failing at the TLS handshake stage before ever becoming a
loggable HTTP request. Fix: enter the address with an explicit `http://` scheme in the
client app rather than a bare host:port.

**Port changed from 8080 to 54280** (user's own request, defense-in-depth — 8080 is
one of the most commonly scanned/default alt-HTTP ports) — updated
`/etc/apache2/ports.conf`, the vhost's `<VirtualHost *:8080>` line, and all three
`trusted_domains` entries to match, then verified all three reachability paths
(localhost, LAN, Tailscale) again after the change.

**Welcome-email test (informational, not fixed by request)**: adding a user and sending
a welcome email reported success in the UI, but `nextcloud.log` showed three real
failures — `Connection could not be established with host "127.0.0.1:25": Connection
refused`. No SMTP transport is configured (`mail_smtpmode` unset, defaults to trying a
local MTA that doesn't exist here — confirmed no `sendmail`/`postfix`/`msmtp`
installed). Deliberately left unconfigured for now per explicit request; the
UI's "success" message should not be trusted for this until a real SMTP relay is set
up.

## Where the chroot's filesystem actually lives (and why the Android File Manager can't see it)

Confirmed directly (`mount` from inside the chroot over SSH): the chroot's root
filesystem is `/dev/block/sda17`, ext4 — a **real, separate partition** on the phone's
physical storage, distinct from both Android's own `/data` partition
(`bootdevice/by-name/userdata`, seen earlier in this doc) and from what Android exposes
to apps as "Internal Storage" (`/storage/emulated/0`). This is also confirmation that
the chroot is not mount-namespaced any more than it's network-namespaced (from earlier
in this doc) — `mount` from inside it shows the real, full system-wide mount table.

Practical consequence: Nextcloud's data directory (`/var/www/nextcloud-data`) is
**structurally invisible** to a stock Android File Manager app, root or not — those
apps are built around Android's own storage abstraction (MediaStore/Storage Access
Framework, which only knows about `/storage/emulated/0` and SD cards), not arbitrary
raw partitions. Seeing this data from the phone itself (rather than through Nextcloud's
own UI, which is the intended path) needs either a root-capable file explorer that can
browse arbitrary mount points, or an SFTP client app pointed at the chroot's own `sshd`.

## Why the chroot's services survive long uptimes without being killed

Empirically observed: Nextcloud/Tailscale/Pi-hole all still running and reachable more
than 12 hours after setup, unattended. Root cause understood, not just observed:

- `apache2`, `mariadb`, `tailscaled`, `pihole-FTL`, `sshd` are plain Linux daemons
  started via this chroot's SysV init — **not Android app processes**. Android's
  aggressive background-killing (Doze, App Standby buckets, the background-app-focused
  low-memory killer) primarily targets processes tied to Android's own app lifecycle
  (spawned via `ActivityManager`/Zygote). Daemons started as root inside a chroot,
  outside that model, are largely invisible to those specific mechanisms.
- The one real Android app in this picture, `com.desktopecho.pideploy` (Pi Deploy)
  itself, **is** subject to normal battery-optimization/Doze restrictions if not
  exempted — checked directly (`dumpsys deviceidle whitelist`) and confirmed it's
  already on the whitelist (`user,com.desktopecho.pideploy,10243`), equivalent to
  "Unrestricted" in Settings → Apps → Battery. Very likely set up deliberately during
  the original Pi-hole/gateway work, which had the same always-on requirement.
- Net effect: both layers (the daemons' own independence from Android's app model, and
  the one real app being explicitly whitelisted) support long unattended uptime — this
  isn't a fragile coincidence, it's two independent, structural reasons.
- Not yet done: actual multi-day logging correlating uptime against battery
  level/system events. `scripts/node-heartbeat.py`/`.sh`
  (`docs/adr/ADR-003-node-agent-model.md`) already exists in this repo for exactly this
  kind of periodic health snapshot but has never been run against this device — a
  natural next step rather than something to build from scratch.

## Reconnecting when USB is unplugged: Wireless debugging

Mid-session, the phone was physically disconnected from the machine driving this whole
build — no cable, no prior `adb tcpip` state (`adb connect <ip>:5555`, the classic
legacy method, came back "Connection refused", confirming that mode wasn't active).
Recovered via Android 11's built-in **Wireless debugging** (Settings → Developer
options → Wireless debugging) — already paired from earlier in this session, just
needed re-enabling. Its connection port **changes every time it's toggled**, unlike the
one-time pairing step — read the current `IP:port` shown on that screen and
`adb connect` to it directly. (Once reconnected, `adb devices -l` may show the same
physical device twice — once via the manual IP:port entry, once via mDNS
auto-discovery as `adb-<serial>-...`. Harmless; use `adb -s <ip:port> ...` to target
unambiguously if `adb shell` errors with "more than one device/emulator".)

## External storage backend decision for donor devices (multi-device storage pooling)

Revisiting the "aggregate storage from multiple phones" idea discussed earlier in this
project: compared FTP, SFTP, and Nextcloud's "Nextcloud (WebDAV)" external-storage
backend as ways to mount a donor device's local storage into this Nextcloud instance.

- **WebDAV backend ruled out** for this use case specifically — it's for connecting to
  *another real WebDAV/Nextcloud server*, not for exposing a phone's local files. A
  donor device would need either a second full Nextcloud install (everything built in
  this doc, again, per device — too heavy) or a standalone WebDAV-only server app
  (much less mature/available on Android than FTP server apps).
  `files_external` app enabled (`occ app:enable files_external`) either way, since it's
  also the shared plumbing for FTP/SFTP mounts.
- **FTP vs SFTP**: FTP is the lighter, more broadly-compatible-with-old-hardware
  choice (unencrypted, but low real risk since this traffic never leaves the home
  LAN — it doesn't cross Tailscale or the internet). SFTP costs more on very old/weak
  devices (needs a newer app like Primitive FTPd, has real if usually small CPU
  overhead for encryption). **Decision made: SFTP**, overriding the
  lighter-weight recommendation, prioritizing encryption over broad old-device
  compatibility — actual device onboarding (Primitive FTPd install, per-device mount
  config) not yet done as of this writing.

## Status at time of writing

- **Remote access: working via Tailscale**, not the originally-planned hand-rolled
  `wg0` + router port-forward (abandoned — confirmed CGNAT, see above). `wg0` has
  since been fully decommissioned. Validated end-to-end from a genuinely external
  network (a second device on mobile data) and from a third, separately-invited
  person's own device via Tailscale's machine-sharing flow — both real "from outside"
  tests, not just LAN.
- **Nextcloud**: installed and verified working (v34.0.3), currently on port
  **54280** (moved from 8080 for defense-in-depth), reachable over localhost, LAN
  (`192.168.88.5:54280`), and Tailscale (`100.80.112.70:54280`).
- **Boot persistence**: Pi Deploy (`com.desktopecho.pideploy`) confirmed to have a
  real `BOOT_COMPLETED` receiver — the chroot and everything registered in its SysV
  runlevels (`sshd`, `pihole-FTL`, `apache2`, `mariadb`, `tailscaled`) should survive a
  phone reboot automatically. Not yet empirically tested with a real reboot, only
  confirmed via the receiver registration.
- **Mail**: deliberately left unconfigured — welcome emails currently fail silently
  behind a misleading "success" UI message (see above). Revisit if/when needed.
- CGNAT is now a moot question for this setup (Tailscale sidesteps it entirely), so it
  was never resolved via the originally-planned Step 9 test — superseded, not solved.
- **Multi-device storage pooling**: the first donor device is now live — see
  `docs/experiments/oneplus-one-sftp-storage-donor.md` for the full write-up (an old
  OnePlus One running Termux + OpenSSH, mounted via the `files_external` SFTP backend
  enabled earlier in this doc).
