#!/bin/bash
#
# provision-nextcloud-storage-donor.sh
#
# One-shot, self-healing provisioning of an Android device (rooted or not) as
# an SFTP storage donor mounted into an ALREADY-RUNNING Nextcloud instance.
# Distilled from the real two-app-failure, one-success build documented in
# docs/experiments/oneplus-one-sftp-storage-donor.md - read that first if
# something here needs deeper "why", this file only carries the "what/how".
#
# GATED ON NEXTCLOUD ALREADY EXISTING. Provisioning a donor before Nextcloud
# is up is useless - this script's first real action (after arg parsing) is
# confirming that, and it refuses to go further if it isn't.
#
# ============================================================================
# HONEST LIMITATION - read this before relying on "self-healing"
# ============================================================================
# `adb shell` (uid `shell`) cannot execute anything inside another app's
# private data directory without root - confirmed directly against a real
# device, not assumed (see the experiment doc). That means Termux's own shell
# can only be driven through its ON-SCREEN terminal (simulated taps and
# keystrokes via `input text`/`keyevent`), never shelled into directly.
# Practical consequences baked into this script:
#   - Those specific steps use generous fixed waits, not true event-driven
#     synchronization, because there's no headless way to know "is the
#     terminal actually ready for input right now".
#   - Every such step is followed by an EXTERNALLY-OBSERVABLE verification
#     (does the SFTP port actually open, checked from the Nextcloud host,
#     not from inside the phone) with automatic retries - this is what makes
#     it self-healing rather than just hopeful.
#   - `input text` on this vintage of Android silently drops the ENTIRE
#     injected string if it contains a literal `&` - confirmed by isolating
#     the failure. This script never puts `&` in an injected command; where
#     backgrounding would normally be needed, it's avoided by design instead
#     (see termux_send, and how sshd/openssh are invoked below).
#   - The device's own screen-off timeout can steal window focus mid-run,
#     silently swallowing subsequent input. This script extends it up front
#     and always re-checks focus before sending anything.
#   - Regular Android apps (including Termux) cannot call `dumpsys <service>`
#     at all (confirmed: real permission error, not a fluke) - which is also
#     why Termux:API doesn't help here even where it would install. Not used
#     by this script for anything.
#
# ============================================================================
# What this script deliberately does NOT automate (needs a human first)
# ============================================================================
#   - Enabling USB/wireless debugging on a virgin device - inherently needs
#     physical interaction with the device's own screen; there is no adb
#     command that can turn on adb before adb works.
#   - The router-side DHCP reservation for the donor's IP - no API access to
#     an arbitrary consumer router. Printed as a manual follow-up at the end.
#   - Rooting the device - out of scope. This script targets the non-root
#     path proven end-to-end in the OnePlus One experiment.
#
# ============================================================================
# Usage
# ============================================================================
#   scripts/provision-nextcloud-storage-donor.sh \
#     --donor-serial <adb-serial-or-ip:port> \
#     --mount-name "My Old Phone Storage" \
#     [--donor-password <password>]    # auto-generated + printed if omitted
#     [--nc-host <ssh-alias>]          # default: 6t
#     [--nc-occ-path <path>]           # default: /var/www/nextcloud/occ
#     [--nc-occ-user <user>]           # default: www-data
#     [--nc-scan-user <user>]          # default: admin (whose file tree to scan the new mount under)
#     [--donor-root <path>]            # default: /storage/emulated/0
#     [--sftp-port <port>]             # default: 8022
#     [--screen-timeout-ms <ms>]       # default: 1800000 (30 min)
#
# Requires: adb (targeting the donor device), ssh access to the Nextcloud
# host already configured under the alias passed to --nc-host, curl.
#
# Design: every phase is idempotent - checks real device/Nextcloud state
# before acting, skips if already satisfied - same pattern already used in
# scripts/vpn-gateway-setup.sh. Re-running this script after a partial
# failure IS the intended recovery path, not a separate cleanup script. Each
# phase also has its own rollback_* function, called automatically if that
# phase fails outright, which undoes ONLY that phase's own partial work -
# not everything before it, since earlier phases are independently safe to
# leave as-is.

set -uo pipefail
# Deliberately NOT `set -e`: phases handle their own errors and call their
# own rollback explicitly. `-e` would abort mid-phase before rollback logic
# gets a chance to run.

# ---------------------------------------------------------------------------
# Defaults (all overridable via flags)
# ---------------------------------------------------------------------------
NC_HOST="6t"
NC_OCC_PATH="/var/www/nextcloud/occ"
NC_OCC_USER="www-data"
NC_SCAN_USER="admin"  # which Nextcloud user's file tree to scan the mount under - override with --nc-scan-user if your instance's admin account isn't literally named "admin"
DONOR_ROOT="/storage/emulated/0"
SFTP_PORT="8022"
SCREEN_TIMEOUT_MS="1800000"
DONOR_SERIAL=""
DONOR_PASSWORD=""
MOUNT_NAME=""

# Pinned, validated APK sources - see the experiment doc for why these exact
# versions and not "latest". Bump deliberately, don't auto-track upstream.
TERMUX_LEGACY_TAG="v0.119.0-beta.3"           # minSdk 21, for API 21-23 devices
TERMUX_MODERN_TAG="v0.118.3"                  # minSdk 24, for API 24+ devices

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()  { echo "[provision] $*"; }
warn() { echo "[provision] WARNING: $*" >&2; }
die()  { echo "[provision] FATAL: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --donor-serial) DONOR_SERIAL="$2"; shift 2 ;;
    --mount-name) MOUNT_NAME="$2"; shift 2 ;;
    --donor-password) DONOR_PASSWORD="$2"; shift 2 ;;
    --nc-host) NC_HOST="$2"; shift 2 ;;
    --nc-occ-path) NC_OCC_PATH="$2"; shift 2 ;;
    --nc-occ-user) NC_OCC_USER="$2"; shift 2 ;;
    --nc-scan-user) NC_SCAN_USER="$2"; shift 2 ;;
    --donor-root) DONOR_ROOT="$2"; shift 2 ;;
    --sftp-port) SFTP_PORT="$2"; shift 2 ;;
    --screen-timeout-ms) SCREEN_TIMEOUT_MS="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

[[ -n "$DONOR_SERIAL" ]] || die "--donor-serial is required (run 'adb devices -l' to find it)"
[[ -n "$MOUNT_NAME" ]] || die "--mount-name is required (this becomes the folder name users see in Nextcloud)"

if [[ -z "$DONOR_PASSWORD" ]]; then
  DONOR_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)"
  GENERATED_PASSWORD=1
else
  GENERATED_PASSWORD=0
  # '&' and '%' both break termux_send's injection (see its own comments) -
  # fail fast here with a clear message instead of deep inside the sshd
  # phase with a cryptic "refusing to inject" error.
  case "$DONOR_PASSWORD" in
    *"&"*|*"%"*) die "--donor-password cannot contain '&' or '%' - both break how this script types it into the device (see termux_send). Pick a password without those characters." ;;
  esac
fi

# ---------------------------------------------------------------------------
# adb / ssh wrappers
# ---------------------------------------------------------------------------
adbd() { adb -s "$DONOR_SERIAL" "$@"; }
ncssh() { ssh "$NC_HOST" "$@"; }
# `ssh host "string"` gets re-tokenized by the REMOTE shell, so arguments
# containing spaces (like a mount name) get silently split apart unless each
# one is individually shell-quoted before crossing that boundary - %q does
# that. Call sites just pass normal, cleanly-quoted bash arguments; this
# function handles the ssh-boundary re-quoting so they don't have to.
occ() {
  local quoted="" a
  for a in "$@"; do
    quoted+=" $(printf '%q' "$a")"
  done
  ncssh "sudo -u $NC_OCC_USER php $NC_OCC_PATH$quoted"
}

# Termux has no `whoami` reachable from plain `adb shell` (that's Android's
# own toolbox shell, a different process/user context from Termux entirely,
# and doesn't even have a whoami binary). Derive Termux's actual username
# the same way Android itself derives it: u0_a<uid-10000> for the primary
# user profile.
donor_termux_user() {
  local uid_num
  uid_num="$(adbd shell dumpsys package com.termux | grep -m1 -oE 'userId=[0-9]+' | grep -oE '[0-9]+' | tr -d '\r')"
  [[ -n "$uid_num" ]] || die "Could not determine Termux's app UID via dumpsys package"
  echo "u0_a$((uid_num - 10000))"
}

# Check TCP reachability of the donor's SFTP port FROM THE NEXTCLOUD HOST -
# that's the reachability that actually matters (the mount connects LAN-side
# from there, not from wherever this script happens to run).
donor_port_reachable_from_nc_host() {
  ncssh "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/${DONOR_IP}/${SFTP_PORT}'" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Termux terminal-injection primitive (the GUI-automation core)
# ---------------------------------------------------------------------------
# Refuses commands containing a literal '&' - confirmed to silently break
# `input text` on old Android. Backgrounding needs are avoided by design in
# every call site below instead of fighting this.
termux_send() {
  local cmd="$1"
  [[ "$cmd" != *"&"* ]] || die "termux_send: refusing to inject a command containing '&' (breaks input text on this Android vintage): $cmd"
  # '%' is input text's OWN escape character (that's what makes our %s space
  # encoding work at all) - a literal '%' already present in $cmd (e.g. a
  # user-supplied password containing "%s") would get decoded a second time
  # by Android alongside our intentional encoding, so the value actually
  # typed on the device would silently differ from $cmd. Reject rather than
  # risk that ambiguity.
  [[ "$cmd" != *"%"* ]] || die "termux_send: refusing to inject a command containing '%' (input text's own escape character - would be ambiguously double-decoded): $cmd"
  local encoded="${cmd// /%s}"
  adbd shell input text "$encoded"
  adbd shell input keyevent 66  # Enter
}

termux_ensure_focused() {
  adbd shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
  local focus
  focus="$(adbd shell dumpsys window windows 2>/dev/null | grep -i mCurrentFocus || true)"
  if [[ "$focus" != *"com.termux"* ]]; then
    adbd shell monkey -p com.termux -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 2
  fi
  # Tap the terminal body to be sure the on-screen keyboard/terminal has
  # focus, not some stray dialog left over from a previous run.
  adbd shell input tap 400 1600 >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Phase: precondition - Nextcloud must already exist and be reachable
# ---------------------------------------------------------------------------
phase_precondition() {
  log "Checking Nextcloud is actually up at $NC_HOST before doing anything else..."
  local status
  status="$(occ status --output=json 2>/dev/null)" || die "Could not reach Nextcloud via 'occ status' on $NC_HOST - fix that first, provisioning a donor before Nextcloud exists is pointless."
  echo "$status" | grep -q '"installed":true' || die "Nextcloud reports not installed on $NC_HOST. Aborting."
  log "Nextcloud confirmed up."

  log "Ensuring files_external app is enabled (safe, idempotent, forward-only - not rolled back on later failure)..."
  occ app:enable files_external >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Phase: donor device diagnostics (read-only, no rollback needed)
# ---------------------------------------------------------------------------
phase_diagnostics() {
  log "Reading donor device info ($DONOR_SERIAL)..."
  adbd get-state >/dev/null 2>&1 || die "adb cannot reach $DONOR_SERIAL - is it connected/authorized? (run 'adb devices -l')"

  DONOR_API="$(adbd shell getprop ro.build.version.sdk | tr -d '\r')"
  DONOR_ABI="$(adbd shell getprop ro.product.cpu.abi | tr -d '\r')"
  DONOR_MODEL="$(adbd shell getprop ro.product.model | tr -d '\r')"
  # head -1: wlan0 can legitimately report more than one inet line (e.g. a
  # transient address during a WiFi reconnect) - without this, DONOR_IP would
  # collapse into a multi-line value that breaks both the /dev/tcp
  # reachability check below and the eventual occ --config host=... value.
  DONOR_IP="$(adbd shell ip addr show wlan0 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | tr -d '\r' | head -1)"

  [[ -n "$DONOR_API" ]] || die "Could not read API level from donor - is it actually connected?"
  [[ -n "$DONOR_IP" ]] || die "Donor has no wlan0 IPv4 address - it needs to be on the same WiFi/LAN as the Nextcloud host before this can work."

  log "Donor: $DONOR_MODEL, API $DONOR_API, $DONOR_ABI, IP $DONOR_IP"

  if [[ "$DONOR_API" -lt 21 ]]; then
    die "API $DONOR_API is older than Termux's oldest available bootstrap (minSdk 21, legacy 'apt-android-5' variant). This device cannot run Termux at all - out of scope for this script."
  fi
}

# ---------------------------------------------------------------------------
# Phase: screen timeout (avoid mid-run focus loss)
# ---------------------------------------------------------------------------
ORIGINAL_SCREEN_TIMEOUT=""
phase_screen_timeout() {
  log "Extending screen timeout to avoid losing focus mid-provisioning..."
  ORIGINAL_SCREEN_TIMEOUT="$(adbd shell settings get system screen_off_timeout | tr -d '\r')"
  adbd shell settings put system screen_off_timeout "$SCREEN_TIMEOUT_MS"
}
rollback_screen_timeout() {
  [[ -n "$ORIGINAL_SCREEN_TIMEOUT" && "$ORIGINAL_SCREEN_TIMEOUT" != "null" ]] || return 0
  log "Rolling back screen timeout to its original value ($ORIGINAL_SCREEN_TIMEOUT)..."
  adbd shell settings put system screen_off_timeout "$ORIGINAL_SCREEN_TIMEOUT"
}

# ---------------------------------------------------------------------------
# Phase: install Termux (idempotent - skips if already present)
# ---------------------------------------------------------------------------
TERMUX_INSTALLED_THIS_RUN=0
phase_install_termux() {
  if adbd shell pm list packages | tr -d '\r' | grep -q '^package:com.termux$'; then
    log "Termux already installed, skipping install."
    return 0
  fi

  log "Termux not present - installing (API $DONOR_API determines which build)..."
  local url tmp_apk
  # Plain `mktemp -d` + fixed filename, not `mktemp -t template.apk` - BSD
  # mktemp (macOS) doesn't do GNU-style X-substitution in a -t template and
  # will happily hand back a path that doesn't actually end in .apk, which
  # `adb install` then rejects outright. This form works identically on
  # GNU and BSD mktemp.
  tmp_apk="$(mktemp -d)/termux.apk"
  if [[ "$DONOR_API" -ge 24 ]]; then
    url="https://github.com/termux/termux-app/releases/download/${TERMUX_MODERN_TAG}/termux-app_${TERMUX_MODERN_TAG}+github-debug_universal.apk"
  else
    url="https://github.com/termux/termux-app/releases/download/${TERMUX_LEGACY_TAG}/termux-app_${TERMUX_LEGACY_TAG}+apt-android-5-github-debug_${DONOR_ABI}.apk"
  fi
  log "Downloading $url"
  # -f: without this, curl exits 0 even on an HTTP error response (e.g. a
  # renamed/removed pinned release asset returning a 404 page), and the
  # 404's HTML body gets written to $tmp_apk as if it were a real APK - the
  # || die below would never fire, and adb install would fail later with a
  # confusing APK-parsing error instead of this script's own clear message.
  curl -sLf "$url" -o "$tmp_apk" || die "Failed to download Termux APK from $url (HTTP error, or the pinned release/asset no longer exists - check TERMUX_LEGACY_TAG/TERMUX_MODERN_TAG)"
  adbd install "$tmp_apk" || die "adb install of Termux failed"
  rm -f "$tmp_apk"
  TERMUX_INSTALLED_THIS_RUN=1
}
rollback_install_termux() {
  [[ "$TERMUX_INSTALLED_THIS_RUN" -eq 1 ]] || return 0
  log "Rolling back: uninstalling Termux (was freshly installed this run, not pre-existing)..."
  adbd uninstall com.termux || true
}

# ---------------------------------------------------------------------------
# Phase: bootstrap + openssh + sshd, verified externally with retries
# ---------------------------------------------------------------------------
phase_setup_sshd() {
  log "Checking whether sshd is already up before touching anything (idempotency check)..."
  if donor_port_reachable_from_nc_host; then
    log "Port $SFTP_PORT already reachable from $NC_HOST - sshd already working, skipping reinstall/password reset entirely."
    DONOR_SSH_USER="$(donor_termux_user)"
    return 0
  fi

  log "Launching Termux and waiting for first-run bootstrap..."
  termux_ensure_focused
  sleep 15  # fixed wait - see HONEST LIMITATION header for why this can't be event-driven

  local attempt
  for attempt in 1 2 3; do
    log "sshd setup attempt $attempt/3..."
    termux_ensure_focused
    termux_send "pkg install openssh -y"
    sleep 20
    termux_ensure_focused
    termux_send "passwd"
    sleep 1
    termux_send "$DONOR_PASSWORD"
    sleep 1
    termux_send "$DONOR_PASSWORD"
    sleep 2
    termux_ensure_focused
    termux_send "sshd"
    sleep 3

    log "Verifying SFTP port $SFTP_PORT is actually reachable from $NC_HOST..."
    if donor_port_reachable_from_nc_host; then
      log "Confirmed: sshd listening and reachable."
      DONOR_SSH_USER="$(donor_termux_user)"
      return 0
    fi
    warn "Port not reachable yet after attempt $attempt - likely a swallowed keystroke or stray dialog. Retrying with a fresh focus check."
  done

  rollback_setup_sshd
  die "sshd never came up after 3 attempts. Manual check needed: run 'adb -s $DONOR_SERIAL exec-out screencap -p > /tmp/donor.png' and open it to see what Termux's screen actually shows."
}
rollback_setup_sshd() {
  log "Rolling back: attempting to stop any stuck sshd process via the Termux terminal..."
  termux_ensure_focused
  termux_send "pkill sshd"
}

# ---------------------------------------------------------------------------
# Phase: wireless adb (convenience - no meaningful rollback, harmless to leave)
# ---------------------------------------------------------------------------
phase_wireless_adb() {
  log "Enabling wireless adb so this device doesn't need to stay USB-tethered..."
  adbd tcpip 5555 >/dev/null 2>&1 || warn "Could not enable tcpip mode (non-fatal, USB adb still works)"
}

# ---------------------------------------------------------------------------
# Phase: Nextcloud external storage mount (idempotent, real rollback)
# ---------------------------------------------------------------------------
MOUNT_CREATED_THIS_RUN=0
MOUNT_ID=""
phase_configure_mount() {
  log "Checking for an existing mount named '$MOUNT_NAME'..."
  local existing
  # MOUNT_NAME is passed via environment, not interpolated into the Python
  # source string - interpolating it directly (e.g. `== '$MOUNT_NAME':`)
  # means a name containing a single quote is parsed as Python code, not
  # data: a SyntaxError that this pipeline previously never checked the
  # exit status of, so `existing` silently came back empty and the script
  # would create a duplicate mount on every re-run instead of detecting the
  # real one - defeating the whole idempotency point of this phase.
  existing="$(occ files_external:list --output=json 2>/dev/null | MOUNT_NAME_ENV="$MOUNT_NAME" python3 -c "
import json, os, sys
target = os.environ['MOUNT_NAME_ENV']
try:
    mounts = json.load(sys.stdin)
except Exception:
    mounts = []
for m in mounts:
    if m.get('mount_point', '').lstrip('/') == target:
        print(m['mount_id'])
        break
")"

  if [[ -n "$existing" ]]; then
    log "Mount already exists (id $existing) - verifying it still works rather than recreating."
    MOUNT_ID="$existing"
  else
    log "Creating new external storage mount..."
    local create_out
    create_out="$(occ files_external:create --output=json "$MOUNT_NAME" sftp password::password \
      --config "host=$DONOR_IP" --config "port=$SFTP_PORT" \
      --config "user=$DONOR_SSH_USER" --config "password=$DONOR_PASSWORD" \
      --config "root=$DONOR_ROOT" 2>&1)"
    # Structured JSON parsing, not "trailing digits of the output" - the old
    # `grep -oE '[0-9]+$' | tail -1` approach would happily grab an unrelated
    # number from any trailing PHP notice/deprecation warning/version nag and
    # treat it as the mount id, silently pointing the later verify/rollback
    # at the wrong storage mount.
    MOUNT_ID="$(echo "$create_out" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data[0]['mount_id'])
except Exception:
    pass
" 2>/dev/null)"
    [[ -n "$MOUNT_ID" && "$MOUNT_ID" =~ ^[0-9]+$ ]] || die "Could not parse a valid mount id from occ output: $create_out"
    MOUNT_CREATED_THIS_RUN=1
  fi

  log "Verifying mount $MOUNT_ID..."
  local verify_out
  verify_out="$(occ files_external:verify "$MOUNT_ID" --output=json 2>&1)"
  echo "$verify_out" | grep -q '"status":"ok"' || {
    rollback_configure_mount
    die "Mount verification failed: $verify_out"
  }
  log "Mount verified working."
}
rollback_configure_mount() {
  [[ "$MOUNT_CREATED_THIS_RUN" -eq 1 && -n "$MOUNT_ID" ]] || return 0
  log "Rolling back: deleting the mount created this run (id $MOUNT_ID), it failed verification..."
  occ files_external:delete -y "$MOUNT_ID" || true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  phase_precondition
  phase_diagnostics

  phase_screen_timeout || { rollback_screen_timeout; die "screen timeout phase failed"; }
  # Every phase from here on already calls die() internally on its own
  # failure path (phase_setup_sshd and phase_configure_mount also call their
  # own rollback_* first) - so `phase_X || { rollback_X; die }` chains here
  # would be unreachable dead code, since die() exits the process before
  # control ever returns to this `||`. A trap is what actually guarantees
  # the screen timeout gets restored regardless of which phase below this
  # point dies, or how.
  trap rollback_screen_timeout EXIT

  phase_install_termux    # dies internally on failure; a failed install leaves no partial state to roll back
  phase_setup_sshd        # dies internally, rolling back its own stuck sshd first
  phase_wireless_adb
  phase_configure_mount   # dies internally, rolling back its own half-created mount first

  log "Scanning the new mount for real content..."
  occ files:scan --path="${NC_SCAN_USER}/files/${MOUNT_NAME}" || warn "Scan failed or found nothing - check manually, mount itself verified OK above. If your instance's admin account isn't literally named 'admin', pass --nc-scan-user."

  trap - EXIT
  rollback_screen_timeout  # done provisioning, restore the device's normal timeout

  cat <<SUMMARY

============================================================================
Done. $DONOR_MODEL is now a Nextcloud storage donor.
============================================================================
  Mount name:      $MOUNT_NAME (id $MOUNT_ID)
  Donor IP:        $DONOR_IP:$SFTP_PORT
  Donor username:  $DONOR_SSH_USER
SUMMARY
  if [[ "$GENERATED_PASSWORD" -eq 1 ]]; then
    cat <<SUMMARY
  Donor password:  $DONOR_PASSWORD   (auto-generated - store this somewhere
                     safe now, it is NOT saved anywhere by this script and
                     will not be shown again)
SUMMARY
  else
    echo "  Donor password:  (the one you passed in via --donor-password)"
  fi
  cat <<SUMMARY

Manual follow-ups this script cannot do for you:
  1. Add a DHCP reservation on your router for $DONOR_IP so it never drifts.
  2. Consider Termux:Boot for reboot persistence if this device might restart
     unattended (not installed by this script - see the experiment doc for
     why Termux:API-equivalent boot persistence needs its own companion app).
============================================================================
SUMMARY
}

main
