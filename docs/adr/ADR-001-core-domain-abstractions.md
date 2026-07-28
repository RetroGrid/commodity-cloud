# ADR-001: Core Domain Abstractions

**Status:** Accepted

**Date:** 2026-07-02

---

# Title

Core Domain Abstractions

---

# Context

Commodity Cloud transforms heterogeneous commodity hardware into a cohesive personal infrastructure platform.

To support long-term evolution, the project defines a stable domain vocabulary independent of implementation details.

These abstractions form the ubiquitous language used throughout the project.

---

# Decision

Commodity Cloud defines the following core domain abstractions.

---

# Infrastructure

An Infrastructure represents the administrative and operational boundary of the platform.

It owns all participating Nodes, Identities, Intents, Policies and Workloads.

Examples include:

- Home
- Office
- Lab
- Small Business
- Cloud Deployment

Infrastructure is the primary aggregate of the domain.

---

# Node

A Node is any computational device capable of participating in an Infrastructure.

Examples include:

- Smartphone
- Tablet
- Laptop
- Desktop
- Raspberry Pi
- NAS
- Router
- Virtual Machine

Nodes provide Resources, Capabilities and Constraints.

Nodes may host multiple Workloads and may fulfil one or more Roles.

---

# Resource

A Resource represents a measurable quantity available on a Node.

Examples include:

- CPU
- Memory
- Storage
- GPU Memory
- Network Bandwidth
- Battery Capacity

Resources are finite and consumable.

> **Amendment — node.json v1 (Issue #1, 2026-07-27):** For the `node.json` schema specifically, Resource is widened beyond strictly consumable quantities to also include intrinsic hardware compatibility facts that aren't allocatable but are still physical properties of the node — e.g. USB port type, supported connectivity standards (Wi-Fi/Bluetooth/cellular). Capability remains reserved for binary/categorical *software-observable* abilities (Root Access, ADB Enabled, Docker Support). GPU Memory and measured Network Bandwidth remain unimplemented in `node.json` v1 — not yet earned by a real device experiment or stated use case (Engineering Principle #1: experiment before abstraction). See `docs/specifications/node.md` for the frozen schema and `docs/decisions/parking-lot.md` for the deferred items.

---

# Capability

A Capability represents something a Node is able to do.

Examples include:

- Root Access
- USB Host
- Docker Support
- Hardware Encryption
- Hardware Virtualization

Capabilities determine workload compatibility.

---

# Constraint

A Constraint represents a limitation affecting a Node.

Examples include:

- Locked Bootloader
- Broken Display
- Swollen Battery
- Unsupported Kernel
- Limited Connectivity

Constraints influence operational decisions.

---

# Intent

An Intent represents a desired outcome for an Infrastructure.

Intent defines **what** the user wishes to achieve without prescribing implementation.

Examples include:

- Personal Cloud
- Media Server
- AI Development Environment
- Backup Solution
- Smart Home

An Infrastructure may contain multiple Intents.

---

# Policy

A Policy represents rules governing how the platform should satisfy one or more Intents.

Examples include:

- Prefer low-power devices
- Never expose services publicly
- Encrypt all storage
- Prefer wired networking

Policies constrain decision making.

---

# Role

A Role represents the responsibility fulfilled by a Node within an Infrastructure.

Examples include:

- Storage Node
- Network Node
- Compute Node
- Backup Node
- AI Node

How Roles are assigned or determined is intentionally left as an implementation concern.

---

# Workload

A Workload represents deployable software managed by Commodity Cloud.

Examples include:

- Pi-hole
- WireGuard
- Nextcloud
- Immich
- Home Assistant
- Monitoring

Workloads consume Resources and require Capabilities.

---

# Identity

An Identity represents a person, service or system interacting with Commodity Cloud.

Authentication mechanisms are implementation details.

Examples include:

- User
- Administrator
- Service Account

---

# Relationship Overview

```text
Infrastructure
├── Identity
├── Intent
├── Policy
├── Node
│   ├── Resource
│   ├── Capability
│   └── Constraint
└── Workload

Role describes the responsibility of a Node within an Infrastructure.
```

---

# Consequences

## Positive

- Stable ubiquitous language.
- Hardware-independent domain model.
- Clear separation between domain concepts and implementation.
- Extensible without changing existing terminology.

## Negative

- Behavioural aspects are intentionally deferred until the architecture phase.

---

# Notes

This ADR defines domain concepts only.

Behaviour such as discovery, scheduling, recommendation, deployment and orchestration will be defined separately during the architecture phase.

Where multiple valid implementations exist, this ADR intentionally avoids selecting one.