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

- Router: TP-Link HX510 (Wi-Fi 6 mesh router/AP, not a modem - real ISP termination is a shared point elsewhere in the building, not accessible). No bridge/IP-passthrough mode available - admin panel only exposes **Access Point** or **Router** mode, and per [TP-Link's own FAQ on the difference](https://www.tp-link.com/us/support/faq/2420/), Access Point mode disables the WAN port and all gateway-dependent features (NAT, routing, VPN) entirely - it's a dumb Wi-Fi/switch extender bridged onto an *existing* network, not a way to hand routing to one nominated device while keeping the router's own Wi-Fi/LAN alive. Ruled out early for this reason.
- Router's own "VPN" feature (sidebar: OpenVPN / PPTP VPN / IPSec VPN / VPN Connections) is **server-only** (inbound remote access into the home LAN while away) - confirmed by reading the actual settings, not assumed. No outbound VPN-client capability, so the router can't be pointed at a third-party endpoint (or at the phone) to do the routing natively. This was explored specifically because it would have let the router's own already-correct native IPv4+IPv6 routing do the work instead of fighting `netd` - would have been a materially simpler architecture if available.
- LAN subnet: `192.168.88.0/24`. Phone already has a static Wi-Fi IP (`192.168.88.5`) from the earlier Pi-hole setup.
- VPN endpoint: ProtonVPN free tier, WireGuard config downloaded from their dashboard (not the ProtonVPN Android app).
- Link medium: USB-C to Ethernet adapter, connected to an HX510 **LAN** port (not WAN).

## Decisions and alternatives considered

- **VPN provider - ProtonVPN free tier, chosen over Windscribe and Cloudflare WARP.** ProtonVPN and Windscribe were both viable (genuine no-cost tiers, not ad-supported "free VPN" apps); ProtonVPN was picked because its free tier exposes a plain downloadable WireGuard config, not just its own Android app - important because a raw `wg-quick` tunnel is far easier to NAT-share with other LAN devices than a commercial app's own `VpnService` tunnel, which fights back on reconnects, battery optimization, and its own internal routing rules. Cloudflare WARP was ruled out - it's a privacy proxy with no exit-country choice, not a VPN server in the sense needed here. Self-hosting (e.g. WireGuard on a cheap VPS) was noted as a lower-risk alternative to relying on a commercial provider's ToS tolerance for "one tunnel routing a whole household," and ties into this project's own roadmap (M1's "WireGuard installation" toolkit item) - not pursued this session, still a live option for later.
- **Protocol - WireGuard over OpenVPN.** Lighter CPU cost, better fit for constrained/older hardware (Engineering Principle #5), and matched what ProtonVPN's free tier could hand us as a plain config file.
- **Topology - three ideas considered, in order, before landing on what was actually built:**
  1. *Router bridge/IP-passthrough mode*, making the phone the real router for the whole LAN. Ruled out - not supported by the HX510 (see Network context).
  2. *Disable the HX510's own DHCP server, have the phone serve DHCP for the whole LAN* (via Pi-hole or `dnsmasq`), so every device is automatically routed through the phone with no per-device config. This is the mechanism intended for the eventual network-wide rollout - the DHCP toggle was confirmed to exist, but it was **not actually flipped this session** (see Outstanding).
  3. *Manual per-device static IP override* (gateway + DNS pointed at the phone), leaving the HX510's DHCP untouched. This is what was actually built and validated today - safest/most reversible starting point (Engineering Principle #7: automate only after manual validation), and it's what proved the phone can do the job at all before committing to a network-wide change.
- **Router's own VPN feature as a shortcut** - considered and ruled out (see Network context) once its settings page was actually read rather than assumed.

## Procedure

1. **Router capability check.** Confirmed HX510 has no bridge/passthrough mode and no separate modem to insert the phone in front of. Confirmed it does have a separate DHCP-server on/off toggle (Network -> LAN Settings), independent of Access Point/Router mode - not used this session, but available for the network-wide rollout next.
2. **Prior art check.** Found [VirtualAP](https://github.com/ravindu644/VirtualAP/), an existing rooted-Android router project supporting WireGuard as an upstream. Its downstream/client-facing side is Wi-Fi-hotspot-only (no wired-Ethernet serving, no DHCP-for-a-LAN-segment mode) - not a fit for a wired handoff, but its documented routing strategy ("policy routing rules pinned above netd's own rule range") validated the general approach used below. Also found ["Android phone as gateway"](https://gist.github.com/updateing/3527984f1de1c1ac24c65b2cf1f650eb), a gist whose `share_tun.sh` script does something we later needed: explicitly flushing `natctrl_FORWARD`/`tetherctrl_FORWARD` before adding rules - the first hint that `netd` itself was going to be the real obstacle, not routing/NAT correctness. A third reference, [WireGuard peer as internet gateway using Android USB tethering](https://gist.github.com/gcleaves/ec7a06f8c0bd436c1bc2eb922a246d26), gave concrete command examples for the closest analog (WireGuard + Android USB tethering as a shared uplink).
3. **Physical setup.** Confirmed via product research that this phone generation's USB-C port is USB 2.0 only (not USB 3.x - a well-documented [OnePlus community complaint](https://community.oneplus.com/thread/480611) for the 6/6T generation), capping real-world throughput around 100Mbps regardless of adapter rating. Empirically confirmed with two real adapters: a **Croma 10-in-1 hub** (Fast-Ethernet-class chipset, only needs USB 2.0 High-Speed signaling) worked, capped at 100Mbps as expected; a **Portronics MPort X1** (Gigabit-rated, almost certainly an ASIX AX88179/Realtek RTL8156-class chipset requiring USB 3.x SuperSpeed) did not enumerate at all. Connected the working adapter's `eth0` to an HX510 LAN port, and verified with a temporary static IP + `ping` that the wired link reaches the router before touching WireGuard/NAT at all.
4. **WireGuard tunnel.** See Observations for the chain of obstacles hit getting `wg-quick up` to succeed at all.
5. **NAT + policy routing** for one manually-configured test device (an Android phone, then an iPad), pointed at the OnePlus 6T's `eth0` IP (`192.168.88.60`) as gateway and DNS. **Scope note:** this validates the gateway mechanism per-device; the HX510's own DHCP server was never actually disabled, so this is not yet a network-wide/automatic rollout - see Outstanding.
6. **netd's tethering enforcement** (see Observations) required going through `ndc` from a real Android shell - reached via `adb pair`/`adb connect` over Wi-Fi using Android 11's built-in **Wireless debugging** (Developer options), specifically so the USB-C port didn't have to be freed up from the Ethernet adapter to get a shell.
7. **Validated on two real devices** (an Android phone and an iPad), both showing the ProtonVPN exit IP for IPv4 traffic, confirmed via correlated packet captures (see Diagnostic techniques below).

## Observations

Every one of these was a genuine, non-obvious blocker - captured here so the next device/session doesn't have to rediscover them. `scripts/vpn-gateway-setup.sh` codifies the parts that are scriptable; the `ndc` part cannot be (see below).

- **No kernel WireGuard.** Kernel 4.9.227 predates Linux 5.6. Fixed with the userspace fallback (`apt-get install wireguard-go`, already packaged in Debian - `wg-quick` picks it up automatically once kernel module creation fails).
- **Missing `resolvconf`.** `wg-quick` needs it to manage DNS; not present in this minimal Pi-hole image. `apt-get install resolvconf` fixed it.
- **No `nf_tables` support in this kernel** (Android/OEM kernels of this vintage stick to legacy `iptables`/`xtables`). `wg-quick` prefers the `nft` binary if it merely exists in PATH, regardless of kernel support, so it failed at the routing/firewall-marking step. Also affects plain `iptables`/`ip6tables` - even after switching to the `iptables-legacy` alternative (`update-alternatives --set iptables /usr/sbin/iptables-legacy`), a required netfilter match module (`xt_addrtype`) turned out to be missing from this kernel too.
- **Fix for both of the above:** added `Table = off` to the WireGuard config's `[Interface]` section, disabling `wg-quick`'s automatic policy-routing/anti-loop setup entirely (which depended on the missing modules) - fine, since NAT/forwarding is hand-rolled anyway in this setup.
- **Two interfaces on the same subnet** (`eth0` at `.60`, `wlan0` at `.5`, both on `192.168.88.0/24`) caused two *separate* problems, not one:
  1. ARP resolution ambiguity when a peer device tries to reach `eth0`'s address directly (a classic "ARP flux" symptom - worth knowing about, didn't end up being the actual return-traffic blocker here).
  2. **The real return-path bug:** `ip route get <dest> from <LAN-client> iif eth0` correctly reports outbound routing via the tunnel, but the *reply* (arriving on the tunnel, destined back to the LAN client) gets routed out `wlan0` instead of `eth0` by the kernel's ordinary route selection between two equally-specific directly-connected routes - silently missing every rule scoped to `eth0`. Fixed with a dedicated policy route: `ip rule add iif proton to $SUBNET lookup 201` + a route in table 201 forcing that specific return path through `eth0` only.
- **The actual root cause, and the hardest one to find:** Android's `netd` enforces a default-deny (`tetherctrl_FORWARD`'s blanket `DROP`) on any forwarded interface pair that hasn't been explicitly authorized through its own tethering subsystem - independent of, and invisible to, correctly-configured `iptables`/`ip route`/`ip rule` state. Confirmed both by content (`iptables -L tetherctrl_FORWARD -n -v` showed a bare `DROP 0.0.0.0/0 -> 0.0.0.0/0`) and by behavior (raw `iptables -I`/`-A` against this chain, or the outer `FORWARD` chain, always fails with `No chain/target/match by that name` - netd's own chains can be *listed* by a foreign `iptables` binary but not *modified* by one). The only fix is `netd`'s own control tool, `ndc` - an Android system binary, not reachable from inside the Pi-hole Debian chroot (different filesystem view, even though networking is shared) - requiring a separate real Android shell:
  ```
  ndc ipfwd enable commoditycloud
  ndc tether interface add eth0
  ndc nat enable eth0 proton 0
  ndc nat enable proton eth0 0
  ```
  The first `nat enable` call authorizes the outbound direction unconditionally and the return direction conditionally on conntrack recognizing the reply as `RELATED,ESTABLISHED` - which never actually matched in practice for this `wireguard-go`/TUN setup (likely a quirk of how a userspace WireGuard implementation re-injects decrypted reply packets into the kernel via the TUN device). Calling it a second time with the interfaces swapped adds a second, unconditional accept that covers the return leg regardless. **Caveat for future Android versions:** `ndc`'s behavior has reportedly [changed/been restricted on Android 14](https://xdaforums.com/t/has-android-14-crippled-the-ndc-command.4645821/) - this exact sequence is confirmed for Android 11 on this device, not guaranteed to carry forward unchanged.
- **State does not persist across reboot/reconnect**, and not just the obvious things: `eth0`'s IP, the policy routes/rules, and (independently, on Android's own schedule) netd's tethering authorization all reset - confirmed this happened at least three separate times in one session, seemingly tied to Android's connectivity stack reacting to network changes. `scripts/vpn-gateway-setup.sh` re-applies everything scriptable from the chroot; the `ndc` sequence above still has to be reapplied manually from ADB each time until this is automated (see Outstanding).
- **IPv6 is not covered.** ProtonVPN's peer does advertise `::/0`, but nothing in this setup touches IPv6 - and critically, disabling `net.ipv6.conf.all.forwarding` on the phone does *not* stop a LAN client from getting its own independent IPv6 address/default route directly from the HX510 via router advertisements (SLAAC), since that's not something we're forwarding at all, it's the client's own separate, uncontrolled path. Confirmed via split results on two different speed-test tools on the same device at the same time: one showing the real ISP location (IPv6 path, bypassing the gateway entirely), the other showing the ProtonVPN exit (IPv4, correctly tunneled). Android's static-IP Wi-Fi settings only expose IPv4 gateway/DNS configuration, so there's no client-side way to force IPv6 through the gateway either.
- **Battery/continuous power is a hard requirement, not a nice-to-have.** Once a device's gateway is pointed at the phone, the phone becomes that device's sole path to the internet - if it loses power, that's a full outage for that device, not degraded service, and there is currently no fallback (confirmed: this design has no path back to the HX510's own routing without manually reverting the device's static IP settings). This gets more consequential, not less, once the network-wide DHCP rollout happens (Outstanding item 2), since it would then affect every device on the LAN simultaneously rather than just manually-configured ones.
- **No fail-open if the VPN endpoint itself goes unresponsive.** Discussed but not implemented: if ProtonVPN's server stops responding, the current design has no mechanism to fall back to direct (unencrypted, non-VPN) internet access - traffic would just stay black-holed. Whether that's the right tradeoff (privacy-safe but zero uptime during an outage) versus a fail-open alternative is an explicit open decision for whoever builds the Phase 2 watchdog, not something to assume either way.
- **Considered using the HX510's own "VPN" feature as a shortcut** - not available (see Network context).
- **Operational note, unrelated to the gateway mechanism itself:** a ProtonVPN WireGuard config (containing a real private key) was accidentally saved directly into this git working directory mid-session. It was never committed/pushed, but it's a reminder to check for this class of accidental secret before staging anything - the file is now renamed with a `.conf` extension and covered by a new root `.gitignore` entry.

## Diagnostic techniques used

Worth preserving as reusable methodology for the IPv6 work and any future debugging of this same class of problem - most of today's session was spent on these, not on the fixes themselves:

- **`ip route get <dest> from <src> iif <iface>`** - simulates the kernel's routing decision for a hypothetical packet without generating real traffic. Used to confirm outbound routing looked correct (it did, immediately) and, separately, to catch the return-path bug (it reported `dev wlan0` for a return packet before the fix, `dev eth0` after) - the single most useful command in this whole session.
- **Correlated `tcpdump` on two interfaces simultaneously** - e.g. `tcpdump -i eth0 -n host <client-ip>` and `tcpdump -i proton -n` at the same time, matching flows by source port across the NAT boundary (since post-NAT, everything on the tunnel side shows the tunnel's own address, not the original client's). This was the only way to get a definitive, non-inferential answer to "is this device's traffic actually reaching the tunnel" - counters and `ip rule`/`ip route get` output alone were repeatedly misleading or incomplete on their own.
- **`conntrack -L`** - used to check for stale/sticky connection-tracking state that might explain traffic silently continuing to use a pre-fix path. Also useful for confirming *which* device's traffic actually reached a given destination when tcpdump output alone was ambiguous.
- **Checking every sub-chain of `FORWARD` individually** (`nm_mdmprxy_iface_pkt_fwder`, `oem_fwd`, `fw_FORWARD`, `bw_FORWARD`, `tetherctrl_FORWARD`), not just the outer chain's policy/counters - the outer `FORWARD` chain's `ACCEPT` policy was actively misleading; the real block was several jumps deep in `tetherctrl_FORWARD`.
- **`iptables -t mangle -L -n -v`** - used to rule out `netd` setting an fwmark on forwarded traffic that could redirect it via a different `ip rule` than expected. Turned out not to be the issue here (none of the mangle rules matched on `eth0`), but was an important elimination step, not a wasted one.
- **`sysctl net.ipv4.conf.<iface>.rp_filter` and `net.ipv4.conf.<iface>.forwarding`** - checked per-interface, not just the global `net.ipv4.ip_forward`, since Linux tracks both separately and the per-interface value can silently differ after an interface reset.
- **ADB over Wi-Fi (Android 11+ Wireless debugging)** rather than USB - let us reach a real Android userspace shell (needed for `ndc`, since it's not reachable from the Debian chroot) without disconnecting the USB-C Ethernet adapter and losing the gateway setup in progress.
- **`iptables -j TRACE` (raw table) / `xtables-monitor --trace`** - researched as the "nuclear option" for tracing a packet's exact path through every netfilter chain, but not ultimately needed - inspecting `tetherctrl_FORWARD`'s contents directly got us the answer first. Worth knowing about ([reference](https://github.com/commonism/iptables-trace)) if a future problem doesn't yield to simpler chain-by-chain inspection.

## Result

**Successful for IPv4**, fully verified end-to-end (real traffic, two independent devices, correlated packet captures on both the LAN-facing and tunnel interfaces, confirmed ProtonVPN exit IP). **IPv6 not implemented** - LAN clients' IPv6 traffic bypasses the gateway entirely rather than leaking through it unencrypted (it never touches the phone's forwarding path at all), but this means it also isn't private the way IPv4 now is.

## Capability Changes

VPN Client (IPv4)        ✅ Proven
VPN Gateway (IPv4)       ✅ Proven - manual per-device gateway/DNS override, validated on 2 devices
VPN Gateway (IPv6)       ❌ Not implemented - client IPv6 bypasses the gateway (see Observations)
Network-wide rollout     ⚠️ Not yet done - HX510's own DHCP server was never disabled; today's validation is per-device, not automatic for new devices joining the LAN

## Outstanding (for a future session)

1. **IPv6 support** - expected to require repeating a comparable chain of fixes (`ip6tables`, a second `ndc` authorization pass, likely the same same-subnet return-routing ambiguity) specifically for the IPv6 stack. Not a quick add-on - budget comparable effort to this entire session.
2. **Network-wide rollout** - disable the HX510's own DHCP server and have the phone (Pi-hole/`dnsmasq`) serve DHCP for the whole LAN, so new devices get the gateway automatically instead of needing manual per-device configuration (see Decisions above for why this was deferred rather than done first).
3. **Persistence across reboot** - `scripts/vpn-gateway-setup.sh` handles everything reapplyable from the chroot; the `ndc` sequence still needs to be run manually from ADB after every reboot/reconnect. A real fix would script the `ndc` calls too (e.g. a small script pushed and run through `adb shell`), and/or feed into the Phase 2 watchdog design already discussed for this experiment.
4. **Battery/continuous-power and fail-open/fail-closed behavior** (see Observations) - confirmed as real constraints, not yet designed around. Whichever watchdog gets built for this needs to account for both.
5. **Architectural note for whoever builds the watchdog:** ADR-003 (node-side agent model) explicitly states the node agent "does NOT execute plans, make decisions" - a self-healing watchdog that restarts services/reapplies rules is a deliberate, narrow exception to that, not an extension of it, and should be documented as such (a short new ADR or an explicit amendment) rather than silently built. Discussed but not written this session.

## Recommendation

Do not recommend automatically.
Require manual validation.
IPv4 gateway functionality is proven and reusable via `scripts/vpn-gateway-setup.sh` + the documented `ndc` sequence. IPv6 and network-wide (automatic) rollout are explicitly out of scope until the Outstanding items above are addressed.

## References

- [VirtualAP](https://github.com/ravindu644/VirtualAP/) - rooted-Android router project; validated the "policy routing pinned above netd's rule range" strategy and confirmed WireGuard-as-upstream is a supported pattern, though its Wi-Fi-hotspot-only downstream ruled it out as a direct fit here.
- ["Android phone as gateway" gist](https://gist.github.com/updateing/3527984f1de1c1ac24c65b2cf1f650eb) - source of the `natctrl_FORWARD`/`tetherctrl_FORWARD`-flushing pattern that first pointed at `netd` as the real obstacle.
- ["WireGuard peer as internet gateway, using Android USB tethering" gist](https://gist.github.com/gcleaves/ec7a06f8c0bd436c1bc2eb922a246d26) - concrete command reference for the closest prior-art analog.
- [TP-Link: Access Point Mode vs Router Mode FAQ](https://www.tp-link.com/us/support/faq/2420/) - confirmed Access Point mode disables gateway-dependent features entirely, ruling out that path for the HX510.
- [XDA Forums: "Has Android 14 crippled the ndc command?"](https://xdaforums.com/t/has-android-14-crippled-the-ndc-command.4645821/) - caveat that the `ndc` sequence documented here is confirmed for Android 11 and may not carry forward unchanged to newer Android versions.
- [iptables-trace](https://github.com/commonism/iptables-trace) - packet-tracing tool researched as a fallback diagnostic technique; not ultimately needed this session but worth knowing about for a harder future case.
