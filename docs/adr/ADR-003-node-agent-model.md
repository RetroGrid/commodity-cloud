# ADR-003: Node-Side Agent Model

**Status:** Accepted

**Date:** 2026-07-13

**Supersedes:** bash prototype (node-heartbeat.sh — Linux/macOS only)

---

## Context

The CLI (provisioner) runs on the operator's laptop. Once a node is provisioned, the laptop has no persistent connection to it.

Without anything running on the node, the platform cannot:

- Detect that a workload has crashed or been overridden (e.g. screen lock defeating the photo frame app)
- Know whether the node is still alive without physically checking it
- Resume or verify a provisioning run that was interrupted

A mechanism is needed for provisioned nodes to report their own state back to the platform.

---

## Decision

Every provisioned node runs a **minimal node agent** whose sole responsibility is to write a health snapshot to a known location at a regular interval.

The agent:

- Writes a `node-status.json` file every 60 seconds
- Reports: timestamp, uptime, active workload name, and resource snapshot (RAM free, storage free)
- Does NOT execute plans, make decisions, or communicate outside the local network
- Does NOT require internet access
- Does NOT require a persistent connection to the provisioner

The CLI reads `node-status.json` when queried. It does not receive push notifications.

---

## Implementation

The canonical implementation is `scripts/node-heartbeat.py` — a single Python 3 script with no third-party dependencies.

It runs on:

| Platform | Runtime | Output path |
|---|---|---|
| Linux | `python3 node-heartbeat.py` | `~/.commoditycloud/node-status.json` |
| macOS | `python3 node-heartbeat.py` | `~/.commoditycloud/node-status.json` |
| Windows | `python node-heartbeat.py` | `%LOCALAPPDATA%\CommodityCloud\node-status.json` |
| Android (Termux) | `python node-heartbeat.py` | `~/.commoditycloud/node-status.json` |
| Android (native) | Background `Service` in workload APK | `/sdcard/commoditycloud/node-status.json` |

The provisioner reads status via:
- **Linux/macOS node:** `ssh user@node cat ~/.commoditycloud/node-status.json`
- **Android node:** `adb shell cat /sdcard/commoditycloud/node-status.json`
- **Windows node:** `ssh user@node type %LOCALAPPDATA%\CommodityCloud\node-status.json`

Python was chosen as the canonical runtime because it is already a declared dependency of the Toolkit (required by `start-transfer.sh`).

---

## node-status.json Schema

```json
{
  "node_id": "galaxy-tab-001",
  "platform": "android-termux",
  "timestamp": "2026-07-13T10:00:00Z",
  "uptime_seconds": 3600,
  "workload": "digitalphotoframe",
  "workload_status": "running",
  "resources": {
    "ram_free_mb": 128,
    "storage_free_gb": 4
  }
}
```

Valid `platform` values: `linux`, `macos`, `windows`, `android-termux`, `android-native`, `unknown`.

---

## What the Agent Deliberately Does Not Do

- Execute scripts or plans
- Accept inbound commands from the network
- Communicate with any external service
- Manage other workloads

Execution authority remains exclusively with the CLI on the provisioner.

---

## Consequences

### Positive

- Nodes are observable without a persistent connection
- Health checks are pull-based — no inbound attack surface on the node
- Works within the constraint that the provisioner is not always on
- The Android implementation reuses the existing app — no separate APK required for v1

### Negative

- 60-second polling means up to 60 seconds of lag before detecting a failure
- ADB/SSH must be available to read status — same constraint as provisioning
- If the agent process itself crashes, there is no status (silent failure)

---

## Linked Work

- `digitalphotoframe` — Android agent is a `Service` added to the existing app
- `commodity-cloud inspect --status` — CLI command that reads node-status.json
- ADR-001: Node Specification — `workload_status` maps to the Node health model (see also PL-007)
