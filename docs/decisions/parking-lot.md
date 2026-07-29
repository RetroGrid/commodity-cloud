# Parking Lot

This document captures architectural and modelling questions that have been intentionally deferred.The parking lot is specifically for unresolved architectural and modelling questions.

The purpose of this document is to prevent analysis paralysis while ensuring important ideas are not forgotten.

---

## Legend

| Field | Description |
|--------|-------------|
| **ID** | Unique identifier for the question |
| **Category** | Area of the platform affected |
| **Priority** | Low / Medium / High |
| **Status** | Deferred, Under Discussion, Resolved |
| **Review Phase** | When the question should be revisited |

---

## PL-001: Role Assignment

**Category:** Domain Model, Scheduling

**Priority:** Medium

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should Roles be:

- assigned before deployment,
- inferred from deployed Workloads,

**Note (added during node.json v1 freeze, Issue #1):** related sub-question surfaced — once role assignment exists, does `node.json.roles` need a way to represent "evaluated and found unsuitable for any role," distinct from "not yet evaluated"? The v1 Inspector omits `roles` entirely rather than guess at this semantics ahead of a real evaluator. Revisit alongside the main question above.
- or support both approaches?

---

## PL-002: Node Discovery

**Category:** Discovery

**Priority:** High

**Status:** Deferred

**Review Phase:** Architecture

### Question

When does a discovered device become a managed Node?

Possible approaches:

- Discovery immediately creates a Node.
- Discovery creates a candidate that becomes a Node after evaluation.
- User explicitly approves discovered devices.

---

## PL-003: Workload Placement

**Category:** Scheduling

**Priority:** High

**Status:** Deferred

**Review Phase:** Architecture

### Question

How should Workloads be matched to Nodes?

Possible factors include:

- Resources
- Capabilities
- Constraints
- Policies
- User preferences

---

## PL-004: Recommendation Strategy

**Category:** Scheduling

**Priority:** Medium

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should Commodity Cloud:

- recommend Workloads,
- recommend complete deployment plans,
- or simply validate user-defined deployments?

---

## PL-005: Role Hierarchy

**Category:** Domain Model

**Priority:** Low

**Status:** Deferred

**Review Phase:** Implementation

### Question

Should Roles have hierarchy or priority?

Examples:

- Primary Role
- Secondary Role

or

- Multiple equal Roles

---

## PL-006: Labels vs Annotations

**Category:** Metadata

**Priority:** Low

**Status:** Deferred

**Review Phase:** Implementation

### Question

Should Commodity Cloud distinguish between:

- Labels (user-defined)
- Annotations (system-generated metadata)

or use a single metadata mechanism?

---

## PL-007: Node Health Model

**Category:** Monitoring

**Priority:** Medium

**Status:** Deferred

**Review Phase:** Monitoring

### Question

How should Node health be represented?

Examples:

- Healthy
- Degraded
- Offline
- Maintenance

Should health belong to the Node specification or the monitoring subsystem?

---

## PL-008: Capability Discovery

**Category:** Discovery

**Priority:** Medium

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should Capabilities be:

- automatically detected,
- manually declared,
- or allow user overrides?

---

## PL-009: Workload Dependencies

**Category:** Workloads

**Priority:** Medium

**Status:** Deferred

**Review Phase:** Workload Specification

### Question

How should dependencies between Workloads be expressed?

Examples:

- Nextcloud depends on a database.
- Home Assistant depends on MQTT.

---

## PL-010: Multi-Infrastructure Management

**Category:** Federation

**Priority:** Low

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should a single Commodity Cloud installation manage multiple Infrastructures?

Examples:

- Home
- Office
- Cloud VPS


---

## PL-011: GPU Memory as a Resource

**Category:** Domain Model

**Priority:** Low

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should GPU Memory be modelled as a `resources` field in `node.json`?

Named as a Resource example in ADR-001, but not implemented in the v1 schema (Issue #1) — no real device experiment or stated use case has required it yet (Engineering Principle #1: experiment before abstraction). Revisit when a GPU-aware workload (likely M6, AI-assisted planning) makes it relevant.

---

## PL-012: Display as a Node property

**Category:** Domain Model

**Priority:** Low

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should display specs (resolution, size) be modelled as a `resources` field, and should "broken display" be a distinct schema concept rather than a free-form `constraints` entry?

Not added to `node.json` v1 — no real device experiment has required structured display data, and the existing DigitalPhotoFrame app already queries display size live via the Android API at runtime, not from `node.json`. "Broken display" is already expressible today as a free-form `constraints` string if a device actually has one — revisit only if a real case shows that's insufficient.

---

## PL-013: Measured Network Bandwidth as a Resource

**Category:** Domain Model

**Priority:** Low

**Status:** Deferred

**Review Phase:** Architecture

### Question

Should measured/live network bandwidth be modelled as a Resource, distinct from `node.json.resources.connectivity` (which records supported standards, not throughput)?

Named as a Resource example in ADR-001, but not implemented — bandwidth is a live/fluctuating value, so if ever added it likely belongs in `node-status.json` (ADR-003) rather than the static `node.json`, consistent with the existing static-vs-live split between the two artifacts. Not earned by a real use case yet.
