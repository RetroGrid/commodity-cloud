# Node Specification

## Purpose

A Node represents a computational device participating in an Infrastructure.

Nodes provide compute, storage and networking resources capable of hosting one or more Workloads.

---

## Responsibilities

A Node is responsible for:

- Providing Resources.
- Advertising Capabilities.
- Reporting Constraints.
- Hosting assigned Workloads.
- Reporting operational health.

---

## Properties

| Property | Required | Description |
|----------|----------|-------------|
| id | Yes (nullable) | Hardware-native identifier (e.g. ADB serial for Android, VM UUID) — not a human-assigned slug. `null` if unreadable; the Inspector must emit a warning when it does. |
| name | Yes | Human-readable name |
| manufacturer | No | Device manufacturer |
| model | No | Device model |
| category | Yes | Device category — enum, see v1 Schema below |
| operatingSystem | Yes | Installed operating system — structured object, see v1 Schema below |
| resources | Yes | Available Resources — structured object, see v1 Schema below |
| capabilities | Yes | Supported Capabilities — free-form string array |
| constraints | No | Known Constraints — free-form string array |
| roles | No | Roles fulfilled within the Infrastructure. **Not populated by the v1 Inspector** — role assignment is parked (see Parking Lot PL-001). Field stays spec-legal for when that's resolved. |
| labels | No | User-defined metadata |
| annotations | No | System-generated metadata |

---

## v1 Schema (frozen — Issue #1)

Concrete JSON shape for the structured properties above. A fully annotated worked example (Samsung Galaxy Tab, SHW-M380W) is at `docs/specifications/node.example.jsonc`.

### `category` (enum)

```
smartphone | tablet | sbc | desktop | laptop | nas | vm | router
```

Closed set for v1. Extend when a real device needs a new value — don't add speculative categories ahead of one.

### `operatingSystem` (object)

```json
{
  "name": "android",
  "version": "4.0.4",
  "apiLevel": 15,
  "distribution": null
}
```

`distribution` (OEM skin or Linux distro, e.g. `"TouchWiz UX"`) is required but nullable — `null` is an explicit assertion that no skin/distro applies, not a stand-in for "not yet checked."

### `resources` (object)

Scope: static/intrinsic hardware facts only — consumable quantities (CPU, RAM, storage, battery) and fixed compatibility facts (USB port type, connectivity standards). Live/current values (free RAM right now, free storage right now) belong in `node-status.json` (ADR-003), not here — the two artifacts are deliberately separate and must not duplicate each other.

```json
{
  "cpu": { "cores": 2, "architecture": "armv7" },
  "ramTotalMb": 1024,
  "storage": [
    { "type": "internal", "totalGb": 32 }
  ],
  "battery": { "designCapacityMah": 7000, "healthPercent": null },
  "usbPortType": "30-pin-proprietary",
  "connectivity": {
    "wifi": { "supported": true, "standard": "802.11n" },
    "bluetooth": { "supported": true, "version": "3.0" },
    "cellular": null
  }
}
```

- `storage`: array, not a scalar — a device can have more than one medium (internal + sdcard). `type` enum (v1): `internal | sdcard`.
- `battery`: required, nullable at the object level. `null` for categories with no inherent battery (`desktop`, `nas`, `vm`, `router`, `sbc`); a populated object for `smartphone`/`tablet`/`laptop`. Sub-fields (e.g. `healthPercent`) are independently nullable if unreadable.
- `usbPortType`: physical connector shape, free string. Distinct from the "USB Host" (OTG) Capability below — do not conflate the two.
- `connectivity.wifi.standard` / `connectivity.bluetooth.version`: free strings, not enums.
- `connectivity.cellular`: nullable — `null` if no modem, else a string (e.g. `"4G LTE"`).
- **Not implemented in v1:** GPU Memory, measured Network Bandwidth. Both are named as Resource examples in ADR-001 but aren't earned by a real device experiment or stated use case yet (Engineering Principle #1) — see ADR-001 amendment and Parking Lot.

### `capabilities` / `constraints` (free-form string arrays)

```json
"capabilities": ["root_access", "adb_enabled"],
"constraints": ["usb_data_unavailable"]
```

No fixed vocabulary in v1 — deliberately, per ADR-002's warning against building a capability catalog ahead of real device experiments. An ability's *absence* from `capabilities` means the device doesn't have it; there is no separate "lacks X" entry (e.g. "not rooted" is simply the absence of `"root_access"`).

---

## Relationships

A Node:

- belongs to one Infrastructure.
- provides Resources.
- provides Capabilities.
- may have Constraints.
- may host multiple Workloads.
- may fulfil multiple Roles.

---

## Examples

Examples of Nodes include:

- OnePlus 6T
- Raspberry Pi 5
- Dell OptiPlex
- Lenovo ThinkCentre
- Synology NAS
- Virtual Machine

A fully worked example (Samsung Galaxy Tab, SHW-M380W) is available at `docs/specifications/node.example.jsonc`.

---

## Open Design Questions

The following questions are intentionally deferred until the architecture phase:

- How are Nodes discovered?
- When does a discovered device become a managed Node?
- How are Roles assigned or determined?
- Can users manually influence Role assignment?
- How are Workloads matched to Nodes?

These questions have multiple valid solutions and will be addressed when designing the platform architecture.