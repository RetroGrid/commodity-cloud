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