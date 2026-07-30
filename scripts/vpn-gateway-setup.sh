#!/bin/bash
# OnePlus 6T VPN gateway experiment - re-applies gateway state that does not
# survive a reboot/reconnect (interface IP, forwarding sysctls, WireGuard
# tunnel, policy routing, NAT). Run as root inside the Pi-hole Debian chroot:
#   bash vpn-gateway-setup.sh
#
# Does NOT touch Pi-hole itself - its DNS service is entirely independent of
# everything below (see vpn-gateway-cleanup.sh for the reverse of this file).
#
# NOT SUFFICIENT ALONE. Android's netd also resets its own tethering
# authorization (tetherctrl_FORWARD chain) independently of everything this
# script does, and that can only be re-applied via `ndc`, which only exists
# in Android's real userspace, not this chroot. After running this script,
# also run from a real Android shell (adb shell -> su):
#
#   ndc ipfwd enable commoditycloud
#   ndc tether interface add eth0
#   ndc nat enable eth0 proton 0
#   ndc nat enable proton eth0 0
#
# See docs/experiments/rooted-oneplus6t-vpngateway.md for why all four of
# those are needed and how this was actually diagnosed.

set -e

ETH_IFACE="eth0"
ETH_IP="192.168.88.60"
SUBNET="192.168.88.0/24"
WG_IFACE="proton"

echo "=== 1. eth0 static IP ==="
# The USB-C-Ethernet adapter's interface (eth0) loses its manually-assigned
# IP repeatedly - observed multiple times in one session, most likely
# Android's own connectivity stack reacting to network changes and touching
# an interface it also independently manages. Re-add only if it's missing.
if ! ip addr show "$ETH_IFACE" | grep -q "$ETH_IP"; then
  ip addr add "$ETH_IP/24" dev "$ETH_IFACE"
fi
# The interface can also end up administratively down; this is harmless to
# repeat even if it's already up.
ip link set "$ETH_IFACE" up
ip addr show "$ETH_IFACE"

echo "=== 2. Forwarding sysctls (IPv4 on, IPv6 off) ==="
# Without this, the kernel won't route packets between interfaces at all -
# it's the most basic prerequisite for acting as a gateway.
sysctl -w net.ipv4.ip_forward=1
# IPv6 forwarding is deliberately left off: LAN clients get their own,
# independent IPv6 address/route directly from the router (SLAAC), which
# this setup does not intercept at all - so there is nothing IPv6-specific
# to forward yet. See docs/experiments/... "IPv6 is not covered" for why
# this doesn't mean IPv6 is safely blocked, just that it's out of scope.
sysctl -w net.ipv6.conf.all.forwarding=0

echo "=== 3. WireGuard tunnel ==="
# wg-quick up depends on the userspace `wireguard-go` fallback (this kernel
# predates Linux 5.6, no native WireGuard module) and the config's
# `Table = off` setting, which skips wg-quick's automatic policy routing -
# that automatic routing depends on kernel netfilter modules (nf_tables,
# xt_addrtype) this kernel doesn't have. Both are one-time setup already
# baked into the installed packages / saved config, not redone here.
# Only bring it up if it isn't already running, to keep this idempotent.
if ! wg show "$WG_IFACE" &>/dev/null; then
  wg-quick up "$WG_IFACE"
fi
wg show "$WG_IFACE"

echo "=== 4. Policy routing (outbound: LAN client -> tunnel) ==="
# Because Table = off, wg-quick sets up none of the routing itself - all of
# it is hand-rolled here, matching the strategy documented by the VirtualAP
# project ("policy routing rules pinned above netd's own rule range").
#
# This first rule makes sure traffic destined back to our own LAN subnet
# always uses the normal main table, so it doesn't get accidentally pulled
# into the VPN-bound table below by the broader rule that follows.
if ! ip rule show | grep -q "to $SUBNET lookup main"; then
  ip rule add from all to "$SUBNET" lookup main pref 7000
fi
# This is the actual "route LAN clients into the tunnel" rule: any packet
# arriving on eth0 (i.e. forwarded from another device on the LAN, not
# something the phone generated itself) gets looked up in table 200 instead
# of the main table.
if ! ip rule show | grep -q "iif $ETH_IFACE lookup 200"; then
  ip rule add from all iif "$ETH_IFACE" lookup 200
fi
# Table 200 only contains one thing: send everything through the tunnel.
if ! ip route show table 200 | grep -q "default dev $WG_IFACE"; then
  ip route add default dev "$WG_IFACE" table 200
fi

echo "=== 5. Policy routing (return path: tunnel -> LAN client, and any other reply to a LAN client) ==="
# This exists because of a genuinely surprising bug: eth0 and wlan0 are both
# on $SUBNET, so anything destined back to a LAN client - not just tunnel
# return traffic, but ANY reply the phone itself generates (a plain ICMP
# ping reply, a Pi-hole DNS response) - hits the same ambiguity: the
# kernel's ordinary route selection between two equally "directly
# connected" routes to $SUBNET can pick wlan0 instead of eth0, silently
# missing every rule (ours and netd's) that's scoped to eth0 specifically,
# and never reaching the LAN client at all (wrong egress interface, wrong
# source address).
#
# First found and fixed narrowly (only "arrived via the tunnel" traffic),
# then found to recur for the phone's own locally-generated replies too -
# a plain `ping`/DNS response never "arrives via iif proton", so that
# narrower rule didn't cover it. This broader version matches ANY traffic
# to $SUBNET regardless of where it originates, so it covers both cases.
# Confirmed directly with:
#   ip route get <lan-client-ip>
# which reported "dev wlan0" before this fix, "dev eth0 table 201" after.
#
# Rule 6998 is deliberately a lower (higher-priority) number than the
# "iif eth0 lookup 200" outbound rule and the "lookup main" fallback below,
# so this always wins for $SUBNET destinations before either of those is
# even considered.
if ! ip rule show | grep -q "to $SUBNET lookup 201"; then
  ip rule add to "$SUBNET" lookup 201 pref 6998
fi
if ! ip route show table 201 | grep -q "dev $ETH_IFACE"; then
  ip route add "$SUBNET" dev "$ETH_IFACE" src "$ETH_IP" table 201
fi
# Print all three so a failure here is immediately visible, not silent.
ip rule show
ip route show table 200
ip route show table 201

echo "=== 6. NAT (MASQUERADE, inserted ahead of netd's own chains) ==="
# Rewrites LAN clients' private source addresses to the tunnel's own
# address before the packet leaves via the tunnel - without this, replies
# from the internet would have nowhere valid to come back to.
#
# Inserted at position 1 (ahead of netd's own POSTROUTING chains, e.g.
# nm_mdmprxy_masquerade_skip) rather than appended, matching the pattern
# used by the VirtualAP project's own working scripts - matches by source
# subnet rather than a specific output interface, so it's not accidentally
# bypassed if routing ever changes.
if ! iptables -t nat -C POSTROUTING -s "$SUBNET" ! -d "$SUBNET" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -I POSTROUTING 1 -s "$SUBNET" ! -d "$SUBNET" -j MASQUERADE
fi
iptables -t nat -L POSTROUTING -n -v

echo "=== 7. netd tetherctrl_FORWARD - CANNOT be fixed from this chroot ==="
# This is the actual root cause behind most of one session's worth of
# debugging: Android's netd enforces a default-deny (a blanket DROP) on any
# forwarded interface pair that hasn't been explicitly authorized through
# its own tethering subsystem - completely independent of, and invisible
# to, correctly-configured iptables/ip route/ip rule state. Confirmed by
# both content (a bare "DROP 0.0.0.0/0 -> 0.0.0.0/0" in this chain) and by
# behavior (raw iptables -I/-A against this chain always fails with
# "No chain/target/match by that name" - netd's own chains can be *listed*
# by a foreign iptables binary but not *modified* by one).
#
# The only fix is netd's own control tool, `ndc` - an Android system
# binary that isn't reachable from inside this Debian chroot (different
# filesystem view, even though networking is shared). This script can only
# report the current state, not fix it - see the header comment and
# docs/experiments/rooted-oneplus6t-vpngateway.md for the exact commands
# to run from a real Android shell (adb shell -> su).
iptables -L tetherctrl_FORWARD -n -v
echo ""
echo "!!! If the chain above still shows only a blanket DROP (no eth0/proton"
echo "!!! ACCEPT rules with real hit counts), run the ndc sequence documented"
echo "!!! at the top of this file from a real Android shell (adb shell -> su)."
echo "!!! Raw iptables cannot write to netd-owned chains - only ndc can."

echo ""
echo "=== Done. Summary ==="
wg show
ip addr show "$ETH_IFACE"
iptables -t nat -L POSTROUTING -n -v
