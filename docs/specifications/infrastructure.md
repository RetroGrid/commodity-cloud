# Infrastructure Specification

## Purpose

An Infrastructure represents the administrative boundary within which Commodity Cloud manages Nodes, Workloads and related domain objects.

It provides the context in which all platform operations occur.

An Infrastructure may represent a home, office, laboratory, cloud deployment or any other logical environment.

---

## Responsibilities

An Infrastructure is responsible for:

- Managing participating Nodes.
- Managing Identities.
- Managing Intents.
- Managing Policies.
- Managing Workloads.
- Maintaining infrastructure-wide configuration.

---

## Properties

| Property | Required | Description |
|----------|----------|-------------|
| id | Yes | Unique identifier |
| name | Yes | Human-readable name |
| description | No | Optional description |
| intents | Yes | Desired outcomes for the Infrastructure |
| policies | No | Rules governing behaviour |
| nodes | Yes | Participating Nodes |
| workloads | Yes | Managed Workloads |
| identities | Yes | Users and service identities |
| labels | No | User-defined metadata |
| annotations | No | System-generated metadata |

---

## Relationships

An Infrastructure:

- owns multiple Nodes.
- owns multiple Workloads.
- owns multiple Policies.
- owns multiple Intents.
- owns multiple Identities.

A Node belongs to exactly one Infrastructure.

---

## Examples

Examples of Infrastructures include:

- Home Lab
- Family Home
- Small Office
- Cloud VPS
- Development Environment

---

## Open Design Questions

The following questions are intentionally deferred until the architecture phase:

- Can multiple Commodity Cloud instances cooperate to manage one Infrastructure?
- Can an Infrastructure span multiple physical networks?
- How are Infrastructure backups performed?
- How is Infrastructure state persisted?