# Review: Architecture, Feedback, and First Code

**Date:** 2026-07-13
**Time:** ~13:30–16:15 IST
**Session type:** Architecture review + hard feedback + first code shipped

---

## Context

This was the first structured review of the CommodityCloud project since M0 (Foundation) was completed. The project had documentation only — no code in the commodity-cloud repo itself, and a partially complete `digitalphotoframe` repo in the same organisation.

---

## State of the Project at the Start of This Session

| Area | Status |
|---|---|
| Vision and principles (ADR-000) | Written |
| Core domain abstractions (ADR-001) | Written |
| Capability-driven composition (ADR-002) | Written |
| Roadmap (M0–M6) | Written |
| Parking lot | Written |
| Engineering principles | Written |
| Toolkit scripts (M1) | 0 in commodity-cloud; 2 in digitalphotoframe (incomplete) |
| Inspector / node.json (M2) | Not started |
| Planner (M3) | Not started |
| Any running code in commodity-cloud | None |

The `digitalphotoframe` repo had:
- A working native Android app (Java, minSdk=15) for the Galaxy Tab
- `start-transfer.sh` / `stop-transfer.sh` — modular shell scripts for APK sideloading
- A Galaxy Tab revival experiment log (Session 1)
- A rooted OnePlus 6T VPN gateway experiment (Procedure: `...` — empty)

---

## Hard Feedback Received

### On the commodity-cloud repo
- Entire repo was documentation with zero runnable code
- The OnePlus experiment had `Procedure: ...` — structurally exists but contains no information
- ADRs written at M0 before any implementation are design essays, not decision records. ADRs earn their validity when tested against real behaviour.
- The domain model (Node, Capability, Intent, etc.) closely mirrors Kubernetes vocabulary — needs a sharper answer to "why not k3s?"

### On the digitalphotoframe repo
- The Galaxy Tab Session 1 log is what the OnePlus experiment should have been — specific failures, specific workarounds, real constraint discovery
- `start-transfer.sh` had state persistence code truncated/missing. `stop-transfer.sh` referenced `.server.pid` and other state files that `start-transfer.sh` never wrote — a real bug, not a WIP comment
- The Android app was well-designed for constrained hardware (OOM prevention, Holo Dark, zero dependencies) but had no health/status mechanism — invisible to any future Inspector

### Staff-level gap summary
- Good systems thinking and architectural vocabulary
- Weak on execution evidence at the start of the session
- No answer to "what have you shipped?"
- No rollback/failure handling design anywhere in the docs

---

## Grill-Me Session — Key Decisions Surfaced

Run as a structured interview. Questions and chosen answers:

| Question | Answer chosen | Assessment |
|---|---|---|
| Who is the first user? | Developer/maker with 2–3 old Android devices and a laptop | Strong — specific and grounded |
| First interaction? | Short questionnaire → planner generates options | Good |
| Discovery mechanism? | Auto-scan + manual fallback | Good |
| First contact with a device? | **USB-only for v1, WiFi is later milestone** | Best answer of session — shows scope discipline |
| ADB prerequisite? | One-time setup guide, honest about the constraint | Mature |
| Planning mechanism? | LLM plan + validation layer | Architecturally correct |
| Validation layer? | JSON schema + capability catalog cross-reference | Strong |
| Partial failure handling? | Pre-flight check before execution | Incomplete — deferred the runtime failure case |
| Runtime failure mid-execution? | Recovered: pre-flight + state report + recovery guide | Good recovery |
| Post-provisioning monitoring? | **Thin agent on each node** | Correct — but not in any ADR or roadmap at the time |

The agent question revealed a genuine architectural gap: the platform had no design for how provisioned nodes report their own health. This gap produced ADR-003.

---

## Architectural Decisions Made This Session

### Provisioner = Laptop (control plane / data plane split)
The operator's laptop runs the CLI (Inspector, Planner, Installer). Commodity nodes are the data plane. This is the Ansible/Terraform model — well-established, justified. The bootstrapping problem (how does a non-technical user install the CLI?) is deferred but acknowledged.

### The provisioner does not provision itself (v1)
A node being provisioned cannot also run the provisioning tool, especially if rooting or reformatting is involved. For v1, the laptop is excluded from the node pool. Treating the laptop as the "last node" is a future upgrade.

### LLM is an optional enhancement tier (not required infrastructure)
ADR-000 states "the platform must never require a third-party vendor account to function." Cloud LLM (AWS/GCP hosted) is an enhancement. Local Ollama is the default path. This was a contradiction that was raised and needed explicit resolution.

### Python as the canonical runtime for toolkit scripts
Shell scripts are platform-specific by definition. Python runs on Linux, macOS, Windows, and Android (Termux) from a single source file. Python is already a declared dependency (`start-transfer.sh` requires Python 3 for the HTTP server). Python was chosen as the toolkit runtime to honour the OS-agnostic principle without per-platform script maintenance.

---

## What Was Built This Session

### ADR-003: Node-Side Agent Model
- Defines pull-based health reporting via `node-status.json`
- Schema with: `node_id`, `platform`, `timestamp`, `uptime_seconds`, `workload`, `workload_status`, `resources`
- Android: background `Service` in the workload APK (deferred to digitalphotoframe repo)
- Linux/macOS/Windows: `node-heartbeat.py`
- Deliberately minimal — agent reports state, does not execute plans

### `scripts/node-heartbeat.py`
- Cross-platform Python 3 heartbeat script (no third-party dependencies)
- Runs on Linux, macOS, Windows, Android (Termux)
- Writes `node-status.json` to `~/.commoditycloud/` (or `%LOCALAPPDATA%\CommodityCloud\` on Windows)
- Tested and running on macOS (Satya's MacBook Pro)

### Bug found and fixed: macOS RAM detection
- Initial implementation used `vm_stat` `Pages free` only (~500MB reported)
- Correct definition of "available" on macOS = `Pages free + Pages inactive + Pages speculative + Pages purgeable`
- Fixed output: ~8,367 MB, matching Activity Monitor
- **Lesson:** Wrong node.json is worse than no node.json — the planner makes confident wrong decisions based on bad Inspector output. Getting RAM detection right on constrained hardware matters for workload placement.

---

## Commits This Session

| Commit | Message |
|---|---|
| `1ff4a45` | ADR-003: node agent model + Linux heartbeat script |
| `7686b01` | Replace bash heartbeat with cross-platform Python implementation |
| `2abb17d` | Fix macOS RAM detection - include reclaimable pages |

---

## Open Questions Surfaced (Not Resolved)

### Windows heartbeat is untested
The Python script has a Windows code path using `wmic`. `wmic` is deprecated and removed in Windows 11. The correct Windows 11 approach uses PowerShell (`Get-CimInstance`). Needs a real Windows device to validate.

### Android native agent design
The ADR calls for a background `Service` in the workload APK. This hasn't been designed or built. Key questions: how does the service survive battery optimisation killing it? How does it write to a path accessible via ADB? Does it require additional permissions?

### node.json for real devices
`node-status.json` is now defined and generated. But `node.json` (the fuller Inspector output — static capabilities, constraints, OS version, hardware model) is not. The Galaxy Tab and OnePlus 6T are the two devices that should have `node.json` files. These can be written manually as the first M2 artifacts.

### Rollback / partial failure handling
Acknowledged as a gap during the grill-me session. Pre-flight reduces the risk. Runtime failures still need a state report + recovery guide mechanism. Not designed yet.

### The Kubernetes question
"Why not k3s?" has not been answered concretely. The platform's differentiation needs to be written down — not as a marketing claim, but as a technical answer grounded in what the platform actually does that k3s cannot.

---

## What to Do Next (Priority Order)

1. **Fix `start-transfer.sh` in digitalphotoframe** — write the missing state files (`.server.pid`, `.firewall_action`, etc.) that `stop-transfer.sh` expects. This is a real bug.

2. **Write `node.json` for the Galaxy Tab manually** — treat it as the first M2 artifact. The schema is in ADR-001 / node.md. Fill it from Session 1 observations.

3. **Complete the OnePlus 6T experiment** — document the actual procedure, actual observations. The empty `Procedure: ...` file is the most visible gap in the project.

4. **Add `node-status.json` write to the digitalphotoframe app** — even writing to `/sdcard/commoditycloud/node-status.json` from the existing slideshow `Service` is enough for the Inspector to read via ADB.

5. **Write `commodity-cloud inspect` CLI stub** — reads `node-status.json` via ADB or SSH and prints it. This is the first M2 deliverable.

---

## Meta-Note on Documentation vs Shipping

The tension between "too much docs, nothing shipped" was raised explicitly this session. The resolution agreed: **no ADR without a code artifact in the same commit**. ADR-003 was written and `node-heartbeat.py` was committed together. This is the pattern going forward.

Documentation is part of the implementation (Engineering Principle 10). But documentation without implementation is architecture fiction.
