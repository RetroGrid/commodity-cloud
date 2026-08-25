---
name: rooted-android-network-gateway
description: Playbook for turning a rooted Android device into a VPN gateway/router for other LAN devices (or debugging one already built) - kernel/hardware capability checks, Android's hidden network-management layers (netd tethering, ip rule catch-alls, CLAT, same-subnet routing ambiguity), IPv6-specific pitfalls, and the proven diagnostic toolbox. Distilled from a real two-session build documented in docs/experiments/rooted-oneplus6t-vpngateway.md. Use whenever setting up, extending, or debugging a rooted Android device acting as network infrastructure (gateway, router, VPN-sharing box) - not just this specific experiment.
---

# Rooted Android as network gateway/router - methodology

This is the accumulated, hard-won methodology from actually building this (not theory). Every item below either caused a real, non-obvious failure or was the specific technique that cracked one. Follow the phases in order - each one is cheaper to get right than the next, and skipping ahead is exactly what cost the most time in the original build.

## Phase 0 - Establish constraints before touching anything

Ask explicitly, don't assume:
- Is changing the home router's own settings acceptable at all (even a supported, reversible toggle like disabling IPv6 or DHCP)? Get an explicit yes/no - this determines which topologies are even on the table.
- Is any risk to *other* devices on the shared LAN acceptable, even temporarily? (Rules out things like a second device emitting competing Router Advertisements, however "standards-based" that might be.)
- What's the actual goal - privacy/ISP-obfuscation only, or also geo-unlocking? This changes whether VPN server/region choice matters and whether "just disable IPv6" is an acceptable final answer.

## Phase 1 - Prior art and provider research (before any hands-on work)

- Search for existing rooted-Android-router projects (e.g. VirtualAP-style tools). Check specifically whether their *downstream/client-facing* side matches your topology (wired vs. Wi-Fi-hotspot) - a project can be excellent prior art for the upstream/VPN side while being the wrong fit for how you need to serve clients.
- For the VPN provider: check whether IPv6 is tier-gated, platform-gated (some providers only expose IPv6 fields in their config generator for specific platform selections like Linux/Android), or per-server (not all servers on a given tier support it) - don't assume any one of these explanations without checking the provider's own docs and trying a different server/platform combination.
- Check whether the provider's *official apps* route IPv6 or simply disable it device-locally to prevent leaks - this is the industry-standard pattern for most commercial VPN clients, and changes what "IPv6 support" should even mean for your project.

## Phase 2 - Hardware/kernel capability checks (fail fast on hard blockers)

Check these before writing any script - each one determines a different fallback:
- Kernel version vs. WireGuard's mainline merge (Linux 5.6) - determines native kernel module vs. the `wireguard-go` userspace fallback.
- `nf_tables` support (`nft -f` a trivial ruleset) - if absent, force the `iptables-legacy` fallback (moving the `nft` binary out of PATH is one way, since `wg-quick` prefers it if merely present regardless of kernel support).
- `xt_addrtype` and other netfilter match modules - if missing, add `Table = off` to the WireGuard config's `[Interface]` to skip `wg-quick`'s automatic policy-routing/anti-loop setup entirely (fine if NAT/forwarding is hand-rolled anyway).
- `ip6table_nat`/`CONFIG_IP6_NF_NAT` presence, specifically, if IPv6 sharing is a goal - `ip6tables -t nat -L` erroring "Table does not exist" is a hard, hardware-level blocker for any hand-rolled NAT66, independent of anything else.
- USB port generation (2.0 vs 3.0) if using a USB-Ethernet adapter - caps real throughput regardless of adapter rating; verify with a real adapter before assuming.

## Phase 3 - Build order (validate each layer before adding the next)

1. Physical/L1: adapter recognized, link up, static IP reaches the router via `ping`.
2. WireGuard tunnel up, handshake confirmed via `wg show`.
3. **Confirm the tunnel itself carries traffic, from the gateway device's own shell, before adding any forwarding/sharing complexity.** With `Table = off`, this needs a manual route added first (`ip route add <target> dev <wg-iface>` or the `-6` equivalent) - a fresh tunnel has zero reachability otherwise, for anyone, since `Table = off` disables *all* automatic route setup, not just the default route.
4. IP forwarding sysctls (`net.ipv4.ip_forward=1`, and the IPv6 equivalent only if actually pursuing IPv6 routing).
5. NAT/MASQUERADE, inserted ahead of the OS's own NAT chains, not appended.
6. Policy routing for LAN-client traffic into the tunnel.
7. **Test from an actual LAN client device, never from the gateway's own shell.** A `curl` run directly on the gateway does not exercise the forwarding path at all (with `Table = off`, the gateway's own traffic never uses the tunnel unless something explicitly routes it there) - this looks like a failure but is testing the wrong thing entirely, and cost real time in the original build.

## Phase 4 - Android's hidden network-management layers (check every one, don't assume any is fine because iptables/ip route "look right")

This is the recurring meta-pattern of the whole project: Android layers its own opaque network management on top of the same kernel primitives, invisible to standard Linux tools until you go looking. Check each of these explicitly:

- **`netd`'s tethering authorization** (`tetherctrl_FORWARD` chain) - `iptables -L tetherctrl_FORWARD -n -v`; a bare `DROP 0.0.0.0/0 -> 0.0.0.0/0` means a default-deny is active regardless of correct routing/NAT elsewhere. Raw `iptables -I`/`-A` against this chain fails with "No chain/target/match by that name" - it can be *listed* by a foreign iptables binary but not *modified*. Fix requires `ndc` (`ipfwd enable`, `tether interface add`, `nat enable <if1> <if2> 0` in both directions) from a **real Android shell** - not reachable from a chroot.
- **Per-network `ip rule` policy routing** - check `ip rule show` *and* `ip -6 rule show` separately; they can differ. Look for `oif <iface> lookup <table>` rules per network Android recognizes, and a terminal catch-all (e.g. `from all unreachable`). An interface you created yourself (like a WireGuard tunnel) won't have a corresponding rule, so traffic bound to it via `SO_BINDTODEVICE` falls through to the catch-all - fixable directly with your own `ip rule add ... lookup main`, mirroring Android's own pattern, no `ndc` needed for this one.
- **CLAT/464xlat auto-provisioning** - check `ip addr show` (full listing) for an unexpected `v4-*`-style interface, and watch for replies in `tcpdump` addressed to a ULA (`fd00::/8`) that shares your real address's interface-identifier suffix but not its prefix - a signature of automatic translation you didn't ask for.
- **Same-subnet multi-interface routing ambiguity** - if the gateway has 2+ interfaces on the same LAN subnet (e.g. both Wi-Fi and a USB-Ethernet adapter), the kernel must arbitrarily pick one for anything destined to that subnet. This affects **two separate cases** - don't assume fixing one covers the other:
  - Tunnel-forwarded return traffic: test with `ip route get <dest> from <remote> iif <wg-iface>`.
  - The gateway's *own* locally-generated replies to a LAN client (a plain ping reply, a local DNS response): test with `ip route get <dest>` - no `from`/`iif` at all, since this simulates a fresh, locally-originated packet.
  A rule/route fix scoped to one case (e.g. `iif <wg-iface> to <subnet> lookup <table>`) will not cover the other; use an unconditional `to <subnet> lookup <table>` rule if both need fixing.
- **State persistence** - assume nothing survives a reboot/reconnect: interface IPs, `ip rule`/`ip route` entries, and (independently, on Android's own schedule) `netd`'s tethering authorization. Build the setup script idempotent from the start. Also don't trust that a route "must still be there" just because a script's own idempotency check passed earlier in the session, or because it printed `RTNETLINK answers: File exists` on a later re-run - always re-verify with `ip route show table <N>` directly when something that was working stops working.

## Phase 5 - IPv6-specific checklist, if pursuing it

- Check the VPN config for an actual IPv6 address in `[Interface] Address` - don't assume tier gating is the reason if it's missing; check whether platform selection in the provider's config-download UI matters, and whether the *specific server* assigned supports it (not all do, even within the same tier).
- Test the tunnel's own IPv6 connectivity from the gateway device first (lowest-risk checkpoint - no forwarding, no NAT, no other device involved) before adding any sharing complexity.
- Remember most commercial VPN clients don't route IPv6 at all - they disable it device-locally specifically to prevent leaks. If the real goal is "no leak" rather than "IPv6 genuinely tunneled," check whether disabling IPv6 at the router (if Phase 0 says that's acceptable) is a much simpler, safer, industry-standard-matching solution than hand-rolling IPv6 NAT/forwarding.
- If a provider-side IPv6 bug is suspected (packets leave fine, replies never arrive correctly), run a differential test against a *different* provider - or a personal device already running a different commercial VPN app - on the same hardware, before concluding it's a hardware/OS-side problem. Two servers from the same provider showing the identical symptom points at the provider's backend, not the server; a different provider working cleanly on the same hardware confirms it further.

## Diagnostic toolbox (the techniques that actually resolved things, most useful first)

- `ip route get <dest> [from <src>] [iif <iface>]` - simulates the kernel's routing decision without generating real traffic. Run it both with and without `iif`/`from` - they test genuinely different cases (forwarded vs. locally-generated traffic).
- Correlated `tcpdump` on two interfaces simultaneously, matching flows by port across a NAT boundary. The single most reliable way to get a non-inferential answer to "is this traffic actually arriving/leaving" - counters and rule dumps alone are often misleading or incomplete.
- `conntrack -L [-f ipv6]` - check for (or rule out) NAT/connection-tracking state explaining an observed symptom.
- Check every sub-chain of `FORWARD` individually, not just the outer chain's policy/counters - the outer chain's `ACCEPT` policy can be actively misleading when the real block is several jumps deep.
- `iptables -t mangle -L -n -v` - rule out an fwmark-based redirect to an unexpected `ip rule` table.
- Per-interface `rp_filter`/`forwarding` sysctls, checked individually, not just the global versions - Linux tracks both separately and they can silently diverge after an interface reset.
- ADB **Wireless debugging** (Android 11+, over Wi-Fi) to reach a real Android userspace shell for `ndc` without disconnecting a USB-based physical link in progress.
- `ip rule show` / `ip -6 rule show`, full dumps, inspected line by line - the fastest way to spot Android's own per-network policy scheme and any terminal catch-all rule.

## Non-negotiables

- Document every blocker, root cause, and fix as you find it, including what's confirmed vs. still a hypothesis - not after the fact. Cite external references.
- Verify from an actual client device, never from the gateway's own shell (see Phase 3, step 7).
- Check `git status` before staging anything after a VPN config download - a config with a real private key landing in a git working directory is an easy, repeat mistake; make sure `.gitignore` covers it before it's ever an option to commit.

Reference implementation and full narrative: `docs/experiments/rooted-oneplus6t-vpngateway.md`, `scripts/vpn-gateway-setup.sh`, `scripts/vpn-gateway-cleanup.sh`.
