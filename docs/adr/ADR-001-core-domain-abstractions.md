# ADR-001: Core Domain Abstractions

**Status:** Accepted

**Date:** 2026-07-02

---

# Title

Core Domain Abstractions

---

# Context

Commodity Cloud aims to transform heterogeneous commodity hardware into a cohesive personal infrastructure platform.

Rather than modelling specific hardware platforms such as phones, tablets, laptops, or Raspberry Pis, the platform models the characteristics and relationships that exist between devices, workloads, and users.

To achieve this, the project defines a common domain language that remains independent of implementation details.

These abstractions form the vocabulary used throughout the platform.

---

# Decision

The platform defines the following core abstractions.

---

# Node

A **Node** is any computational device capable of participating in the platform.

Examples include:

- Smartphone
- Tablet
- Laptop
- Desktop
- Mini PC
- Raspberry Pi
- NAS
- Router
- Thin Client
- Virtual Machine
- Cloud Instance

A Node is the primary unit managed by the platform.

Nodes possess Resources, Capabilities and Constraints.

Nodes may be assigned one or more Roles.

A Node remains the same logical entity even if its operating system or software changes.

---

# Resource

A **Resource** represents a measurable quantity available on a Node.

Resources are finite and consumable.

Examples include:

- CPU
- Memory
- Storage
- GPU Memory
- Network Bandwidth
- Battery Capacity

Resources determine whether a Node has sufficient capacity to host a Workload.

---

# Capability

A **Capability** represents something a Node is able to do.

Capabilities are qualitative rather than quantitative.

Examples include:

- Root Access
- USB Host
- Bluetooth
- Docker Support
- Hardware Encryption
- GPU Acceleration
- Camera
- Hardware Virtualization

Capabilities determine whether a Workload is compatible with a Node.

---

# Constraint

A **Constraint** represents a limitation affecting a Node.

Constraints may be permanent or temporary.

Examples include:

- Locked Bootloader
- Broken Display
- Swollen Battery
- Unsupported Kernel
- Read-only Filesystem
- Limited Connectivity

Constraints influence workload suitability and scheduling decisions.

---

# Workload

A **Workload** represents any deployable software or service managed by Commodity Cloud.

Examples include:

- DNS Server
- VPN
- NAS
- Media Server
- Monitoring
- AI Inference
- Home Automation
- Backup Service

A Workload consumes Resources and requires Capabilities.

Multiple Workloads may coexist on a single Node, subject to available Resources and applicable Constraints.

---

# Policy

A **Policy** represents user intent.

Policies define the desired behaviour of the platform without prescribing implementation.

Examples include:

- Prefer low-power devices
- Never expose services publicly
- Encrypt all storage
- Minimize battery usage
- Prefer wired networking
- Keep AI workloads isolated

Policies influence workload placement and infrastructure decisions.

---

# Role

A **Role** represents the responsibility assigned to a Node within an infrastructure.

Roles are not intrinsic properties of hardware.

They are derived from available Resources, Capabilities, Constraints and Policies.

Examples include:

- Storage Node
- Network Node
- Compute Node
- Gateway
- Backup Node
- Monitoring Node
- AI Node

A Node may hold multiple Roles simultaneously.

Roles may change over time without changing the identity of the Node.

---

# Identity

An **Identity** represents a person, service or system interacting with Commodity Cloud.

Identity is independent of any authentication mechanism or identity provider.

Authentication is considered an implementation detail.

Examples include:

- Local User
- Administrator
- Service Account
- External Identity Provider

Identity enables authentication, authorization and ownership across the platform.

---

# Relationship Overview

```text
                    Identity
                        │
                        ▼
                     Policy
                        │
                        ▼
                  Infrastructure
                        │
                        ▼
                 Assigns Role(s)
                        │
                        ▼
                      Node
              ┌─────────┼─────────┐
              ▼         ▼         ▼
        Resource   Capability  Constraint
              ▲
              │
              ▼
           Workload
```

---

# Consequences

## Positive

- Hardware-independent domain model.
- Stable vocabulary across the project.
- Clear separation between domain concepts and implementation.
- Supports heterogeneous hardware from the outset.
- Allows future expansion without changing existing abstractions.

## Negative

- Requires careful discipline when introducing new concepts.
- Initial modelling effort is higher than immediately implementing features.

---

# Future Work

Future ADRs will further define:

- Node Model
- Resource Model
- Capability Model
- Constraint Model
- Workload Model
- Identity Model
- Recommendation Architecture
- Deployment Architecture

---

# Notes

This ADR intentionally defines **domain concepts only**.

Software components such as discovery engines, recommendation engines, deployment engines, schedulers and agents are implementation concerns and will be defined in later ADRs.