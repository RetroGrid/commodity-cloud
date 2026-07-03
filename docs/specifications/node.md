# Node Specification

## Purpose

A Node represents a computational device that participates in an Infrastructure.

Nodes provide compute, storage and networking resources capable of hosting one or more Workloads.

A Node is the fundamental execution unit managed by Commodity Cloud.

---

## Responsibilities

A Node is responsible for:

- Advertising its Resources.
- Advertising its Capabilities.
- Reporting its Constraints.
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
| category | Yes | Device category (phone, tablet, laptop, SBC, VM, etc.) |
| operatingSystem | Yes | Installed operating system |
| resources | Yes | Available Resources |
| capabilities | Yes | Supported Capabilities |
| constraints | No | Known Constraints |
| roles | No | Assigned Roles |
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
- may be assigned multiple Roles.

---

## Examples

Examples of Nodes include:

- OnePlus 6T
- Raspberry Pi 5
- Dell OptiPlex
- Lenovo ThinkCentre
- Synology NAS
- Virtual Machine