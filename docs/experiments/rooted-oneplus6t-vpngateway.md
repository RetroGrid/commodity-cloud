# Experiment

## Question

Can a rooted OnePlus 6T replace a Raspberry Pi as a VPN gateway?

## Motivation

Users may not own Linux hardware.

## Device

OnePlus 6T
Android 11
Rooted
Kernel 4.9.227-perf+ (aarch64) - predates WireGuard's mainline merge (Linux 5.6), no native kernel module
Pi-hole via Pi Deploy (chroot-based Debian environment sharing Android's real kernel network stack - not network-namespaced)

## Network context

- Router: TP-Link HX510 (Wi-Fi 6 mesh router/AP, not a modem - real ISP termination is a shared point elsewhere in the building). No bridge/IP-passthrough mode available (only Access Point / Router mode), and Access Point mode disables the WAN port and all gateway features - not usable for this experiment. Router's own "VPN" feature is server-only (inbound remote access), not a client - can't be pointed outward at a third-party endpoint.
- LAN subnet: 192.168.88.0/24. Phone already has a static Wi-Fi IP (192.168.88.5) from an earlier Pi-hole setup.
- VPN endpoint: ProtonVPN free tier, WireGuard config downloaded from their dashboard (not the ProtonVPN Android app - a raw `wg-quick` tunnel is far easier to NAT-share than an app's own `VpnService` tunnel).
- Link medium: USB-C to Ethernet adapter, connected to an HX510 LAN port (not WAN).

## Procedure

1. **Router capability check.** Confirmed HX510 has no bridge/passthrough mode and no separate modem to insert the phone in front of. Confirmed it does have a separate DHCP-server on/off toggle (Network -> LAN Settings), independent of Access Point/Router mode - not used in this session (see Scope below), but available for a future network-wide rollout.
2. **Prior art check.** Found [VirtualAP](https://github.com/ravindu644/VirtualAP/), an existing rooted-Android router project supporting WireGuard as an upstream. Its downstream/client-facing side is Wi-Fi-hotspot-only (no wired-Ethernet serving, no DHCP-for-a-LAN-segment mode) - not a fit for a wired handoff, but its documented routing strategy ("policy routing rules pinned above netd's own rule range") validated the general approach used below. Also found a gist ("Android phone as gateway") whose `share_tun.sh` script does something we later needed: explicitly flushing `natctrl_FORWARD`/`tetherctrl_FORWARD` before adding rules - the first hint that netd itself was going to be the real obstacle, not routing/NAT correctness.
3. **Physical setup.** USB-C-Ethernet adapter (confirmed via `/sys/bus/usb/devices/*/speed`-equivalent reasoning: this phone's USB-C port is USB 2.0 only, not USB 3.x - a known OnePlus 6T generation limitation - so any adapter caps around 100Mbps regardless of its own rating; a cheap Fast-Ethernet-class adapter works fine, a Gigabit-class one may not enumerate at all) connected phone's `eth0` to an HX510 LAN port. Verified with a temporary static IP + `ping` that the wired link reaches the router before touching WireGuard/NAT at all.
4. **WireGuard tunnel.** See Observations for the four separate obstacles hit getting `wg-quick up` to succeed at all.
5. **NAT + policy routing** for one manually-configured test device (Android phone, then an iPad), pointed at the OnePlus 6T's `eth0` IP (`192.168.88.60`) as gateway and DNS. **Scope note:** this validates the gateway mechanism per-device; the HX510's own DHCP server was never actually disabled, so this is not yet a network-wide/automatic rollout - see Outstanding below.
6. **netd's tethering enforcement** (see Observations) required going through `ndc` from a real Android shell (`adb shell` over Wi-Fi, no USB/cable needed - "Wireless debugging" in Developer Options, Android 11+) since it cannot be fixed via raw `iptables` from the chroot.
7. **Validated on two real devices** (an Android phone and an iPad), both showing the ProtonVPN exit IP for IPv4 traffic.

## Observations

Every one of these was a genuine, non-obvious blocker - captured here so the next device/session doesn't have to rediscover them. `scripts/vpn-gateway-setup.sh` codifies the parts that are scriptable; the `ndc` part cannot be (see below).

- **No kernel WireGuard.** Kernel 4.9.227 predates Linux 5.6. Fixed with the userspace fallback (`apt-get install wireguard-go`, already packaged in Debian - `wg-quick` picks it up automatically once the kernel module creation fails).
- **Missing `resolvconf`.** `wg-quick` needs it to manage DNS; not present in this minimal Pi-hole image. `apt-get install resolvconf` fixed it.
- **No `nf_tables` support in this kernel** (Android/OEM kernels of this vintage stick to legacy `iptables`/`xtables`). `wg-quick` prefers the `nft` binary if it merely exists in PATH, regardless of kernel support, so it failed at the routing/firewall-marking step. Also affects plain `iptables`/`ip6tables` - even after switching to the `iptables-legacy` alternative (`update-alternatives --set iptables /usr/sbin/iptables-legacy`), a required netfilter match module (`xt_addrtype`) turned out to be missing from this kernel too.
- **Fix for both of the above:** added `Table = off` to the WireGuard config's `[Interface]` section, disabling `wg-quick`'s automatic policy-routing/anti-loop setup entirely (which depended on the missing modules) - fine, since NAT/forwarding is hand-rolled anyway in this setup.
- **Two interfaces on the same subnet** (`eth0` at `.60`, `wlan0` at `.5`, both on `192.168.88.0/24`) caused two *separate* problems, not one:
  1. ARP resolution ambiguity when a peer device tries to reach `eth0`'s address directly (worth knowing about, didn't end up being the actual blocker here).
  2. **The real return-path bug:** `ip route get <dest> from <LAN-client> iif eth0` correctly reports outbound routing via the tunnel, but the *reply* (arriving on the tunnel, destined back to the LAN client) gets routed out `wlan0` instead of `eth0` by the kernel's ordinary route selection between two equally-specific directly-connected routes - silently missing every rule scoped to `eth0`. Fixed with a dedicated policy route: `ip rule add iif proton to $SUBNET lookup 201` + a route in table 201 forcing that specific return path through `eth0` only.
- **The actual root cause, and the hardest one to find:** Android's `netd` enforces a default-deny (`tetherctrl_FORWARD`'s blanket `DROP`) on any forwarded interface pair that hasn't been explicitly authorized through its own tethering subsystem - independent of, and invisible to, correctly-configured `iptables`/`ip route`/`ip rule` state. Confirmed both by content (`iptables -L tetherctrl_FORWARD -n -v` showed a bare `DROP 0.0.0.0/0 -> 0.0.0.0/0`) and by behavior (raw `iptables -I`/`-A` against this chain, or the outer `FORWARD` chain, always fails with `No chain/target/match by that name` - netd's own chains can be *listed* by a foreign `iptables` binary but not *modified* by one). The only fix is `netd`'s own control tool, `ndc` - which is an Android system binary, not reachable from inside the Pi-hole Debian chroot (different filesystem view, even though networking is shared) - requiring a separate real Android shell via `adb shell` (Wireless debugging, Android 11+, no cable needed) with `su`:
  ```
  ndc ipfwd enable commoditycloud
  ndc tether interface add eth0
  ndc nat enable eth0 proton 0
  ndc nat enable proton eth0 0
  ```
  The first `nat enable` call authorizes the outbound direction unconditionally and the return direction conditionally on conntrack recognizing the reply as `RELATED,ESTABLISHED` - which never actually matched in practice for this `wireguard-go`/TUN setup (likely a quirk of how a userspace WireGuard implementation re-injects decrypted reply packets into the kernel via the TUN device). Calling it a second time with the interfaces swapped adds a second, unconditional accept that covers the return leg regardless.
- **State does not persist across reboot/reconnect**, and not just the obvious things: `eth0`'s IP, the policy routes/rules, and (independently, on Android's own schedule) netd's tethering authorization all reset - confirmed this happened at least three separate times in one session, seemingly tied to Android's connectivity stack reacting to network changes. `scripts/vpn-gateway-setup.sh` re-applies everything scriptable from the chroot; the `ndc` sequence above still has to be reapplied manually from ADB each time until this is automated (see Outstanding).
- **IPv6 is not covered.** ProtonVPN's peer does advertise `::/0`, but nothing in this setup touches IPv6 - and critically, disabling `net.ipv6.conf.all.forwarding` on the phone does *not* stop a LAN client from getting its own independent IPv6 address/default route directly from the HX510 via router advertisements (SLAAC), since that's not something we're forwarding at all, it's the client's own separate, uncontrolled path. Confirmed via split results on two different speed-test tools on the same device at the same time: one showing the real ISP location (IPv6 path, bypassing the gateway entirely), the other showing the ProtonVPN exit (IPv4, correctly tunneled). Android's static-IP Wi-Fi settings only expose IPv4 gateway/DNS configuration, so there's no client-side way to force IPv6 through the gateway either.
- **USB-C port on this phone is USB 2.0 only** (not USB 3.x, a known limitation of this phone generation) - caps real-world throughput around 100Mbps regardless of the adapter's own rating. A Gigabit-class adapter may not enumerate at all on this port; a cheap Fast-Ethernet-class one works and hits its expected ~100Mbps ceiling.
- Considered using the HX510's own "VPN" feature as a shortcut (point the router itself at the phone, letting the router's already-correct native IPv4+IPv6 routing do the work instead of fighting `netd`). Not available - that feature is VPN *server* only (inbound remote access into the home LAN), not a client.

## Result

**Successful for IPv4**, fully verified end-to-end (real traffic, two independent devices, correlated packet captures on both the LAN-facing and tunnel interfaces, confirmed ProtonVPN exit IP). **IPv6 not implemented** - LAN clients' IPv6 traffic bypasses the gateway entirely rather than leaking through it unencrypted (it never touches the phone's forwarding path at all), but this means it also isn't private the way IPv4 now is.

## Capability Changes

VPN Client (IPv4)        ✅ Proven
VPN Gateway (IPv4)       ✅ Proven - manual per-device gateway/DNS override, validated on 2 devices
VPN Gateway (IPv6)       ❌ Not implemented - client IPv6 bypasses the gateway (see Observations)
Network-wide rollout     ⚠️ Not yet done - HX510's own DHCP server was never disabled; today's validation is per-device, not automatic for new devices joining the LAN

## Outstanding (for a future session)

1. **IPv6 support** - expected to require repeating a comparable chain of fixes (`ip6tables`, a second `ndc` authorization pass, likely the same same-subnet return-routing ambiguity) specifically for the IPv6 stack. Not a quick add-on.
2. **Network-wide rollout** - disable the HX510's own DHCP server and have the phone (Pi-hole) serve DHCP for the whole LAN, so new devices get the gateway automatically instead of needing manual per-device configuration.
3. **Persistence across reboot** - `scripts/vpn-gateway-setup.sh` handles everything reapplyable from the chroot; the `ndc` sequence still needs to be run manually from ADB after every reboot/reconnect. A real fix would script the `ndc` calls too (e.g. via a small script pushed and run through `adb shell`), and/or feed into the Phase 2 watchdog design already discussed for this experiment.
4. Battery/continuous-power requirement and VPN-endpoint-unresponsive fail-open/fail-closed behavior were discussed but not implemented this session - still open design questions for the watchdog.

## Recommendation

Do not recommend automatically.
Require manual validation.
IPv4 gateway functionality is proven and reusable via `scripts/vpn-gateway-setup.sh` + the documented `ndc` sequence. IPv6 and network-wide (automatic) rollout are explicitly out of scope until the Outstanding items above are addressed.
