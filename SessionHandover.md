# Commodity Cloud — Session Handoff: Issue #1 (node.json Schema Freeze)

Generated 2026-07-28, for continuation in Claude Code. This doc is self-contained — no prior chat context assumed.

Repo: `RetroGrid/commodity-cloud` (docs + toolkit). Related repo: `RetroGrid/digitalphotoframe` (Android app + transfer scripts) — untouched this session except where noted.

---

## ⚠️ Verify before merging the open PR

1. **File format risk — check this first.** The schema example file was authored as `.jsonc` (JSON-with-comments): a top version/changelog header using `//` syntax, plus originally inline per-field comments. The user removed the inline field comments partway through (kept the top changelog block only), then placed the final file as `docs/specifications/examples/node_example.json` — note the **`.json` extension**, not `.jsonc`. **Comments are not valid in strict JSON.** If the top `// ==== node.json — v1.2 ... ====` header block is still present in a file with a `.json` extension, any standard parser (`json.loads`, `JSON.parse`, `jq`, a future Inspector script, etc.) will fail on it. Before merging: confirm either (a) the header was converted to something JSON-legal (e.g. a `_meta` key) or stripped when the file was finalized, or (b) the extension should actually be `.jsonc`. This is the same failure class ("wrong node.json is worse than no node.json") the project already hit once with the macOS RAM-detection bug — don't let it recur silently.
2. Run `grep -rn "node.example" docs/` — the original patch referenced `docs/specifications/node.example.jsonc` (flat path). User confirmed they corrected references after moving the file to `specifications/examples/`, but the filename/extension also changed (`node_example.json` vs `node.example.jsonc`) — worth a final sweep to catch any stale reference before merge, not just trusting the earlier confirmation.
3. Confirm `wifi.standard` (`"802.11n"`) and `bluetooth.version` (`"3.0"`) in the committed example — as of the last version I generated (v1.2) these were still marked UNCONFIRMED/illustrative, not verified against the physical unit. Unclear if this was checked before commit.

---

## Locked — v1 node.json schema (Issue #1, fully resolved this session)

```json
{
  "id": "<hardware serial, e.g. ADB serial — nullable, warn on null>",
  "name": "Galaxy Tab",
  "manufacturer": "Samsung",
  "model": "SHW-M380W",
  "category": "tablet",
  "operatingSystem": {
    "name": "android",
    "version": "4.0.4",
    "apiLevel": 15,
    "distribution": "TouchWiz UX"
  },
  "resources": {
    "cpu": { "cores": 2, "architecture": "armv7" },
    "ramTotalMb": 1024,
    "storage": [{ "type": "internal", "totalGb": 32 }],
    "battery": { "designCapacityMah": 7000, "healthPercent": null },
    "usbPortType": "30-pin-proprietary",
    "connectivity": {
      "wifi": { "supported": true, "standard": "802.11n" },
      "bluetooth": { "supported": true, "version": "3.0" },
      "cellular": null
    }
  },
  "capabilities": [],
  "constraints": ["usb_data_unavailable"]
}
```
(`roles` intentionally absent — see decisions below.)

### Key decisions and rationale
- **`category`**: closed enum — `smartphone | tablet | sbc | desktop | laptop | nas | vm | router`. Extend only when a real device needs a new value.
- **`operatingSystem`**: structured, not a flat string. `distribution` required-but-nullable (OEM skin/distro; `null` is an explicit assertion, not "not yet checked").
- **`resources` — governing rule (the one to remember if this gets re-litigated):** Resource is widened beyond ADR-001's strict "consumable quantity" definition to also include intrinsic hardware compatibility facts (USB port type, connectivity standards) — because these are physical properties of the node, not something a workload allocates/depletes. `capabilities` stays reserved for binary/categorical *software-observable* abilities (root access, ADB enabled, Docker). This widening is written explicitly into an ADR-001 amendment, not left implicit.
- **`resources` vs `node-status.json`**: `node.json.resources` = static capacity only. Live/current values (free RAM, free storage right now) belong in `node-status.json` (ADR-003) — the two artifacts are deliberately separate and must not duplicate.
- **`storage`**: array, not scalar — supports multiple mediums (internal + sdcard) per device.
- **`battery`**: nullable at the object level — `null` for categories with no inherent battery (`desktop`/`nas`/`vm`/`router`/`sbc`); populated object otherwise. `healthPercent` independently nullable — **confirmed as a genuine null on this device**, not a gap: Android 4.0.4 (API 15) has no battery-health API, with or without root. This is a real finding, not missing data.
- **`usbPortType`**: distinct field from the ADR-001 "USB Host" (OTG) Capability — do not conflate physical connector shape with OTG-host ability.
- **`capabilities`/`constraints`**: free-form strings, no fixed vocabulary — per ADR-002's explicit warning against building a catalog ahead of real device experiments. An ability's *absence* from `capabilities` means the device doesn't have it (e.g. "not rooted" = no separate entry needed).
- **`id`**: the actual hardware-native serial (ADB serial for Android), not a human slug — `name` holds the human-friendly label instead. Required-but-nullable; Inspector must print a warning if null. Real use case: `adb -s <serial>` is required to target a specific device once more than one is connected — directly relevant to the toolkit scripts still to be built (criterion #3), since this project has two real Android devices.
- **`roles`**: omitted entirely from v1 Inspector output — role assignment is parked (PL-001). Reserving "explicitly evaluated as unsuitable" semantics now, with no evaluator to test it against, would repeat the GPU-memory/display over-design mistake.
- **Explicitly NOT implemented in v1** (moved to `docs/decisions/parking-lot.md` as PL-011/012/013, not just dropped): GPU Memory, display specs, measured Network Bandwidth. None earned by a real device experiment or stated use case yet (Engineering Principle #1).

---

## Artifacts produced / patches (this session)

- `docs/specifications/node.md` — patched with the frozen v1 schema section (property table + shapes above)
- `docs/adr/ADR-001-core-domain-abstractions.md` — patched with a blockquote amendment under the Resource section, documenting the widened definition. Original ADR text untouched, amendment appended.
- `docs/decisions/parking-lot.md` — patched: PL-011 (GPU Memory), PL-012 (Display), PL-013 (measured Network Bandwidth) added; PL-001 amended with a roles-suitability sub-question note rather than duplicated as a new entry.
- `docs/specifications/examples/node_example.json` — worked example for the real Galaxy Tab (see file-format warning above).
- `node-json-schema-decisions.md` — scratch/working doc used during design. **Its content is now fully distributed** across the three patched files above. Safe to delete once the PR is merged and confirmed — not yet explicitly deleted as of this handoff.

---

## Completed this session (full list)

1. Root `.gitignore` added (runtime state files) — closed
2. Runtime state files consolidated into `.runtime/` (`start-transfer.sh`/`stop-transfer.sh` updated) — closed. Real bug found+fixed by user post-refactor: firewall block/unblock read the wrong filename after rename, self-diagnosed via manual `socketfilterfw --listapps` check (not just "script ran without error").
3. `node.json` v1 schema fully designed, documented, and patched (see above)
4. Real hardware identified: Samsung Galaxy Tab = **SHW-M380W** (Galaxy Tab 10.1 Wi-Fi, Tegra 2, 2011). Real specs confirmed via web research + physical verification: 1GB RAM, 7000mAh battery, 32GB storage, 30-pin proprietary port (not micro-USB — corrected an aggregator site's wrong claim), TouchWiz UX (corrected an earlier wrong "stock Android" assumption), Wi-Fi-only (no cellular).
5. GitHub Kanban board: "Review/Test" status column added (found under the Kanban board itself, not GitHub Projects v2 field settings)
6. PR raised for the `node.json` schema freeze changes — **pending review/merge**

---

## Outstanding items

1. **PR review + merge** — blocked on file-format verification above
2. **`node-status.json` / `node_id` correlation** — real gap: `node-heartbeat.py` derives `node_id` from hostname, won't match `node.json.id` (hardware serial). Separate GitHub issue, not folded into Issue #1. Command to file it (adjust `--project` if you want it on the board directly):
   ```bash
   gh issue create \
     --repo RetroGrid/commodity-cloud \
     --title "Align node-status.json node_id with node.json id (hardware serial)" \
     --label "m1-m2,inspector,docs" \
     --body-file - <<'EOF'
   ## Problem
   node.json.id (Issue #1 schema) is the device's hardware-native identifier
   (e.g. ADB serial). node-status.json's node_id (scripts/node-heartbeat.py,
   ADR-003) currently derives from socket.gethostname().split(".")[0] —
   a hostname, not a serial. On Termux/Android this is unlikely to match.
   Without a shared identifier, the two artifacts can't be correlated for
   the same physical device.

   ## Scope
   - Update node-heartbeat.py to derive node_id the same way node.json.id
     is derived, or accept it as an injected value.
   - Update ADR-003's worked example ("galaxy-tab-001") or footnote it.
   - Decide the null-serial fallback consistently with node.json.id
     (null + warning, no generated UUID).

   ## Out of scope
   This touches already-shipped, already-tested ADR-003 code —
   deliberately not folded into the Issue #1 schema-freeze ticket.
   EOF
   ```
   Not confirmed whether this has been run yet.
3. **Battery cycle-count spike** (optional, time-boxed) — investigate whether Samsung diagnostic codes expose cycle count on this device generation. Likely finding: not available without root, if at all. Not committed to; "will check."
4. **Delete `node-json-schema-decisions.md`** once PR is merged and its content confirmed fully present in `node.md` / `ADR-001` / `parking-lot.md`.
5. **Naming note, low priority:** Session 1 log's "Kite software" is very likely a misremembering of **Samsung Kies** (the real PC sync suite for this device era). User flagged this with low confidence ("I think... have forgotten the name"). Not corrected anywhere yet — worth fixing if the Session 1 log or memory gets touched again, not urgent.

---

## Next up (per the original M1/M2 sprint recap, once Issue #1 fully closes)

Per the sprint's 7 success criteria, still at 0/7 on the toolkit/Inspector deliverables themselves (only docs + schema are done):
- **Discovery script** (criterion #1) — one command detects the Galaxy Tab over ADB, confirms authorized
- **Inspector script** (criterion #2) — generates a real `node.json` against the now-frozen schema, zero placeholder fields
- **3 toolkit scripts** (criterion #3) — APK install, ADB-enabled check, battery-opt-exempt check. Note: will need `adb -s <serial>` targeting the moment both real Android devices are connected simultaneously — this is exactly why `id` was designed as the hardware serial, not a slug.
- **OnePlus 6T VPN experiment doc** (criterion #7) — user is doing this over a weekend with a real device session; intentionally not filled from memory, do not draft it speculatively.

## Engineering rule in effect (established prior session, reinforced this one)

No design decision recorded without a working code artifact in the same commit. This session's ADR-001/parking-lot amendments were written and patched alongside the schema, not as free-standing essays — keep that pattern for whatever comes next.