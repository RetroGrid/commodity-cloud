#!/bin/bash
# Reverses everything vpn-gateway-setup.sh does, restoring the phone to a
# plain Pi-hole box with no VPN-gateway role.
#
# PREREQUISITE: same as vpn-gateway-setup.sh - the Pi Deploy Debian chroot
# must already be booted and running; this only works run from inside it.
#
# Run as root inside the Pi-hole Debian chroot: bash vpn-gateway-cleanup.sh
#
# Pi-hole itself is completely unaffected by this script. Its DNS service
# (port 53) never depended on the WireGuard tunnel, NAT rule, or policy
# routes below - those only ever governed *forwarded* traffic passing
# through the phone on behalf of other devices. Any device still pointed
# at this phone for DNS will keep resolving normally after this runs; it
# just won't have its other traffic routed through the VPN anymore.
#
# This does NOT need to be run before unplugging the Ethernet adapter or
# power-cycling the phone - none of this state survives that anyway (see
# vpn-gateway-setup.sh's comments). It's for reverting cleanly *without*
# doing either of those.
#
# Partially revokes netd's own tethering authorization via `ndc` from a real
# Android shell (adb shell -> su) - see the bottom of this file. Only 2 of
# the 4 `ndc` commands vpn-gateway-setup.sh's header documents as required
# (the `nat enable` pair) are reversed there. `ndc ipfwd enable commoditycloud`
# and `ndc tether interface add eth0` are NOT reversed by this script - their
# symmetric-looking inverses weren't verified working this session, and
# guessing at unverified `ndc` syntax felt riskier than leaving this a known,
# explicit gap. Full `ndc` authorization scripting (setup AND teardown) is
# tracked separately in GitHub issue #14, not silently assumed done here.

set -e

ETH_IFACE="eth0"
SUBNET="192.168.88.0/24"
WG_IFACE="proton"

echo "=== 1. WireGuard tunnel down ==="
# Tears down the tunnel interface entirely. Since the config uses
# Table = off, there's no automatic routing for wg-quick to clean up here -
# only the interface itself.
if wg show "$WG_IFACE" &>/dev/null; then
  wg-quick down "$WG_IFACE"
fi

echo "=== 2. Remove NAT rule ==="
# Undoes the MASQUERADE rule inserted ahead of netd's own POSTROUTING
# chains. Safe to attempt even if it's already gone (the -C check first
# avoids an error in that case).
if iptables -t nat -C POSTROUTING -s "$SUBNET" ! -d "$SUBNET" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -D POSTROUTING -s "$SUBNET" ! -d "$SUBNET" -j MASQUERADE
fi

echo "=== 3. Remove policy routing ==="
# Removes the three rules/tables added for outbound (LAN client -> tunnel)
# and return-path (tunnel -> LAN client) routing. `ip rule del` on a rule
# that no longer exists just errors quietly here without stopping the
# script, since none of this is critical-path for the revert.
ip rule del from all to "$SUBNET" lookup main pref 7000 2>/dev/null || true
ip rule del from all iif "$ETH_IFACE" lookup 200 2>/dev/null || true
ip rule del to "$SUBNET" lookup 201 pref 6998 2>/dev/null || true
# Tables 200/201 themselves don't need separate deletion - an unreferenced
# routing table with no rule pointing at it is simply inert.

echo "=== 4. Forwarding sysctls back off ==="
# Optional, but restores the phone to "just a Pi-hole box" rather than
# "a box that forwards IPv4 but not IPv6" - matches its state before this
# experiment touched it. Harmless to leave on if preferred; not required
# for Pi-hole, which doesn't need IP forwarding at all.
sysctl -w net.ipv4.ip_forward=0

echo "=== Done. Remaining state (for confirmation) ==="
ip addr show "$ETH_IFACE"
iptables -t nat -L POSTROUTING -n -v
ip rule show

echo ""
echo "!!! One more step, from a real Android shell (adb shell -> su), to"
echo "!!! revoke the NAT portion of netd's tethering authorization for this"
echo "!!! interface pair (this does NOT reverse 'ndc ipfwd enable' or"
echo "!!! 'ndc tether interface add eth0' from setup - see the header comment"
echo "!!! above for why, and GitHub issue #14 for full ndc automation):"
echo ""
echo "    ndc nat disable eth0 proton 0"
echo "    ndc nat disable proton eth0 0"
echo ""
echo "!!! Not strictly required - this authorization doesn't survive a"
echo "!!! reboot/reconnect anyway - but keeps things clean if you're staying"
echo "!!! on the same boot session."
