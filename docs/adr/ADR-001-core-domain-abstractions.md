# ADR-001: Core Domain Abstractions

**Status:** Accepted

**Date:** 2026-07-02

---

# Title

Core Domain Abstractions

---

# Context

Commodity Cloud aims to transform heterogeneous commodity hardware into a cohesive personal infrastructure platform.

Rather than modelling specific hardware platforms such as smartphones, tablets, laptops, or Raspberry Pis, the platform models the characteristics and relationships that exist between devices, workloads, and users.

To achieve this, the project defines a common domain language that remains independent of implementation details.

These abstractions form the vocabulary used throughout the platform.

---

# Decision

Commodity Cloud defines the following core domain abstractions.

---

# Infrastructure

An **Infrastructure** represents the administrative and operational boundary of the platform.

It owns all participating Nodes, Identities, Intents, Policies and Workloads.

An Infrastructure represents a complete deployment, such as:

- Home
- Office
- Lab
- Holiday Home
- Small Business
- Classroom

An Infrastructure is the primary aggregate of the domain.

---

# Node

A **Node** is any computational device capable of participating in an Infrastructure.

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

Nodes provide Resources, Capabilities, and Constraints.

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
- Docker Support
- Hardware Encryption
- Bluetooth
- Camera
- Hardware Virtualization

Capabilities determine whether a Workload is compatible with a Node.

---

# Constraint

A **Constraint** represents any limitation affecting a Node.

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

# Intent

An **Intent** represents a desired outcome for an Infrastructure.

Intent describes **what** the user wants to achieve without specifying how it should be implemented.

Examples include:

- Personal Cloud
- Media Server
- Secure Remote Access
- AI Development Environment
- Smart Home
- Backup Solution

An Infrastructure may have multiple Intents.

Intents drive Recommendations.

---

# Policy

A **Policy** represents rules and preferences governing how the platform should satisfy an Intent.

Policies constrain or guide decision making.

Examples include:

- Prefer low-power devices
- Never expose services publicly
- Encrypt all storage
- Minimize battery usage
- Prefer wired networking
- Keep AI workloads isolated

Policies influence Recommendations but do not define desired outcomes.

---

# Role

A **Role** represents a responsibility assigned to a Node within an Infrastructure.

Roles are derived from:

- Available Resources
- Available Capabilities
- Existing Constraints
- Infrastructure Intents
- Infrastructure Policies

Examples include:

- Storage Node
- Network Node
- Compute Node
- Gateway
- Backup Node
- Monitoring Node
- AI Node

A Node may hold multiple Roles simultaneously.

Roles may change throughout the lifetime of an Infrastructure without changing the identity of the Node.

---

# Workload

A **Workload** represents any deployable software or service managed by Commodity Cloud.

Examples include:

- DNS Server
- VPN
- NAS
- Monitoring
- Media Server
- Home Automation
- AI Inference
- Backup Service

Workloads consume Resources and require Capabilities.

Workloads are deployed onto Nodes according to assigned Roles.

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
                  Infrastructure
                         │
     ┌───────────────────┼────────────────────┐
     │                   │                    │
     ▼                   ▼                    ▼
 Identity             Intent              Policy
                            │               │
                            └──────┬────────┘
                                   ▼
                          Recommendation
                                   │
                                   ▼
                                 Role
                                   │
                                   ▼
                               Workload
                                   │
                                   ▼
                                 Node
                     ┌─────────────┼─────────────┐
                     ▼             ▼             ▼
                Resource     Capability    Constraint
```

---

# Consequences

## Positive

- Provides a stable ubiquitous language.
- Clearly separates user intent from operational policy.
- Separates domain concepts from implementation.
- Supports heterogeneous hardware from the outset.
- Enables future expansion without changing existing abstractions.

## Negative

- Requires discipline when introducing additional concepts.
- Initial modelling effort is greater than immediately implementing features.

---

# Future Work

Subsequent ADRs will define:

- Infrastructure Model
- Node Model
- Resource Model
- Capability Model
- Constraint Model
- Identity Model
- Recommendation Architecture
- Deployment Architecture

---

# Notes

This ADR intentionally defines **domain concepts only**.

Software components such as discovery services, recommendation engines, deployment engines, schedulers and agents are implementation concerns and are intentionally excluded from this document.