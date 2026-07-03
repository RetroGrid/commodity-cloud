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
| id | Yes | Unique identifier |
| name | Yes | Human-readable name |
| manufacturer | No | Device manufacturer |
| model | No | Device model |
| category | Yes | Device category |
| operatingSystem | Yes | Installed operating system |
| resources | Yes | Available Resources |
| capabilities | Yes | Supported Capabilities |
| constraints | No | Known Constraints |
| roles | No | Roles fulfilled within the Infrastructure |
| labels | No | User-defined metadata |
| annotations | No | System-generated metadata |

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

---

## Open Design Questions

The following questions are intentionally deferred until the architecture phase:

- How are Nodes discovered?
- When does a discovered device become a managed Node?
- How are Roles assigned or determined?
- Can users manually influence Role assignment?
- How are Workloads matched to Nodes?

These questions have multiple valid solutions and will be addressed when designing the platform architecture.