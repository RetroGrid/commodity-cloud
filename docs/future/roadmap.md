# Commodity Cloud Roadmap

## Guiding Principle

Build a working system first.

Each milestone should produce something usable and independently testable.

Complexity must be earned.

---

# M0 - Foundation

## Goal

Establish the project structure and architectural direction.

### Deliverables

- [x] Project Vision
- [x] ADR framework
- [x] Initial ADRs
- [x] Documentation structure
- [x] Parking Lot
- [x] Roadmap
- [x] Learn section

---

# M1 - Automation Toolkit

## Goal

Build reusable scripts that automate common tasks.

### Android

- Install APK
- Push/Pull files
- Enable ADB
- Configure device
- Disable battery optimizations (where possible)

### Linux

- Docker installation
- WireGuard installation
- Pi-hole installation
- System updates

### Networking

- DNS testing
- Connectivity checks
- Health checks

Deliverable:

A repository of reusable scripts that work independently of any AI.

---

# M2 - Inspector

## Goal

Discover node capabilities.

Examples:

- CPU
- RAM
- Storage
- Operating System
- Android Version
- Docker Installed
- VPN
- SSH
- Available Ports

Output:

node.json

---

# M3 - Planner

## Goal

Read node metadata and recommend workloads.

Examples:

Input:

- User goals
- node.json
- Capability catalogue

Output:

Recommended deployments.

Initially this should be rule-based.

No AI required.

---

# M4 - Installer

## Goal

Use the toolkit scripts to deploy workloads.

Examples

- Install Pi-hole
- Install Syncthing
- Install Jellyfin
- Configure Docker
- Configure WireGuard

---

# M5 - Dashboard

## Goal

Display all managed nodes.

Show:

- Health
- Installed services
- Storage
- CPU
- Memory
- Logs

---

# M6 - Intelligence

## Goal

Introduce AI-assisted planning.

Examples

- Capability reasoning
- Infrastructure recommendations
- Cost optimisation
- Power optimisation

This milestone should consume the existing knowledge base:

- ADRs
- Learn
- Capability Catalogue

---

# Future

Future ideas are intentionally excluded from this roadmap.

Examples:

- Multi-agent architecture
- SLM hierarchy
- Fine-tuning
- Autonomous remediation
- Distributed planning

These belong in:

/future/architecture-evolution.md