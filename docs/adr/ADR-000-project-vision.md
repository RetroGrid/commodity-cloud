# ADR-000: Project Vision

**Status:** Accepted

**Date:** 2026-07-02

---

# Title

Project Vision and Guiding Principles

---

# Context

Modern households accumulate a growing number of unused computing devices:

- Smartphones
- Tablets
- Laptops
- Mini PCs
- Thin Clients
- Single Board Computers
- NAS devices
- Routers
- Virtual Machines

Most of these devices are retired because they no longer provide a satisfying end-user experience, not because they lack computational capability.

Despite this, these devices are often powerful enough to run infrastructure workloads such as:

- DNS
- VPN
- File Storage
- Backup
- Monitoring
- Automation
- Home Assistant
- Password Managers
- Media Servers
- AI Inference
- Containerized Services

At the same time, self-hosting remains inaccessible for many users due to the complexity of:

- Hardware selection
- Operating systems
- Networking
- Containers
- Security
- Storage
- Reverse proxies
- Authentication
- Deployment

As a result, users frequently purchase new hardware despite already owning capable devices.

---

# Problem Statement

There is currently no unified platform capable of:

- Discovering available hardware
- Understanding hardware capabilities
- Evaluating hardware constraints
- Recommending appropriate workloads
- Deploying services automatically
- Managing heterogeneous consumer hardware as a cohesive personal cloud

---

# Vision

Enable anyone to transform idle commodity hardware into secure, private, self-hosted infrastructure with minimal technical knowledge.

The platform should make reusing existing hardware easier than purchasing new hardware.

---

# Mission

> Transform idle hardware into useful infrastructure.

---

# Philosophy

Computing power is abundant.

Millions of capable devices remain unused because they no longer satisfy modern consumer expectations—not because they lack computational value.

We believe infrastructure should be built from available resources before new hardware is purchased.

This project exists to:

- Lower the barrier to self-hosting
- Extend the useful life of consumer hardware
- Reduce electronic waste
- Return ownership of infrastructure to individuals

---

# Guiding Principles

## 1. Hardware First

The platform reasons about hardware capabilities rather than specific device models.

Hardware is treated as a collection of resources and capabilities.

---

## 2. Heterogeneous by Design

The platform is designed for mixed environments.

Supported platforms may include:

- Android
- Linux
- Windows
- macOS
- Raspberry Pi
- NAS devices
- Virtual Machines
- Future platforms

No operating system receives privileged treatment.

---

## 3. Recommendation Before Deployment

The system first determines what a node is capable of before recommending workloads.

Deployment is a consequence of capability analysis.

---

## 4. Declarative

Users describe desired outcomes rather than implementation steps.

Example:

> Build me a personal cloud.

instead of

> Install Docker, configure Samba, create VPN users...

---

## 5. Local First

Infrastructure is primarily deployed inside the local network.

Internet exposure must always be explicit and secure.

---

## 6. Ownership First

Users own:

- Their infrastructure
- Their data
- Their identities
- Their policies

The platform must never require a third-party vendor account to function.

Identity providers should be pluggable.

Examples include:

- Local Accounts
- LDAP
- Active Directory
- OAuth
- Keycloak
- Authentik
- Future providers

---

## 7. Privacy by Default

The platform should:

- Avoid telemetry by default
- Avoid unnecessary external communication
- Prefer local processing whenever practical

---

## 8. Sustainable Computing

Extending the useful life of existing hardware is preferred over recommending new purchases whenever practical.

---

## Design Principles

Commodity Cloud is guided by the following principles:

### Outcome-Oriented

Users describe the outcomes they want to achieve rather than the infrastructure they wish to manage.

### Intelligent by Default

The platform recommends and, where appropriate, automatically provisions a configuration that best satisfies the user's intents and policies using the available hardware.

### Commodity First

The platform prioritizes the reuse of existing commodity hardware before recommending new hardware.

### Progressive Complexity

The platform provides sensible defaults for most users while allowing advanced users to customize behaviour when required.

### Earning Complexity

Commodity Cloud should earn its complexity.

# Non-Goals

This project is **not** intended to:

- Replace Kubernetes
- Replace Proxmox
- Replace enterprise orchestration systems
- Replace public cloud providers
- Manage hyperscale infrastructure
- Require users to understand infrastructure concepts.
- Expose topology as the primary configuration mechanism.
- Optimize exclusively for high-performance or enterprise-scale deployments.

The target audience is:

- Individuals
- Families
- Makers
- Developers
- Small offices
- Educational institutions

---

# Success Criteria

A non-expert user should be able to:

1. Discover available devices.
2. Understand what each device is capable of.
3. Build a personal cloud using existing hardware.
4. Deploy infrastructure with minimal manual intervention.
5. Maintain that infrastructure with minimal ongoing effort.

---

# Future Direction

This ADR intentionally focuses on the project vision rather than implementation.

Future ADRs will define:

- Core abstractions
- Capability model
- Node model
- Scheduling
- Recommendation engine
- Deployment engine
- Identity model
- Agent architecture

---

# Summary

The project aims to democratize self-hosting by transforming idle commodity hardware into reusable infrastructure.

Rather than requiring users to understand hardware compatibility, networking, deployment, and infrastructure management, the platform should discover available resources, recommend suitable workloads, and automate deployment while preserving privacy, ownership, and sustainability.