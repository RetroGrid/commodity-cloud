# Commodity Cloud — Product Vision

**Status:** Draft
**Document Owner:** RetroGrid
**Last Updated:** 2026-08-26

---

## 1. Vision

Commodity Cloud aims to make the capabilities of hardware people already own useful again.

People have retired phones, tablets, laptops, desktops, Raspberry Pis, storage devices, and other capable hardware sitting unused or underutilized. Much of this hardware can still perform useful functions, but turning it into reliable infrastructure typically requires technical knowledge, manual configuration, and ongoing administration.

Commodity Cloud exists to close that gap.

> **Turn the hardware you already own into useful infrastructure, without requiring deep systems-administration expertise.**

The long-term vision is for a user to bring their existing hardware and their desired outcome, while Commodity Cloud determines what is possible, recommends a suitable workload, helps deploy it, and supports its management over time.

---

## 2. The Problem

The problem is not primarily a lack of computing hardware.

The problem is the gap between:

**What users already have**

and

**What they know how to do with it.**

A retired device may still have useful:

* CPU capacity
* memory
* storage
* networking
* displays
* cameras
* sensors
* battery power
* connectivity
* other hardware capabilities

However, turning those capabilities into useful infrastructure often requires knowledge of:

* operating systems
* Linux administration
* containers
* networking
* SSH
* ADB
* VPNs
* service configuration
* security
* monitoring

This creates unnecessary friction.

As a result, users may leave capable hardware unused, dispose of it, or purchase new hardware for workloads that existing devices could potentially perform.

Commodity Cloud seeks to make existing hardware the starting point rather than the limitation.

---

## 3. Product Definition

Commodity Cloud is a platform for discovering, understanding, utilizing, and managing commodity hardware as useful infrastructure.

For the purposes of this product, **infrastructure** means the computing resources, services, and supporting capabilities required to perform a useful workload.

At a high level:

```text
Hardware You Own
       ↓
     Discover
       ↓
      Inspect
       ↓
   Understand
   Capabilities
       ↓
   What Can It Do?
       ↓
 Recommend Workload
       ↓
     Deploy
       ↓
     Manage
       ↓
    Monitor
```

Commodity Cloud should hide unnecessary technical complexity while exposing enough information for users to understand and trust what is happening.

---

## 4. The Product Promise

Commodity Cloud should answer three fundamental questions for a user:

### 1. What do I have?

Identify and understand the devices available to the user.

### 2. What can I do with it?

Translate hardware capabilities into useful workloads and infrastructure possibilities.

### 3. Can you make it happen?

Help deploy and manage the selected workload with minimal technical intervention.

The product should move the user from:

> "I have an old device."

to:

> "This device is useful for this purpose, and Commodity Cloud can help me make it happen."

---

## 5. Who We Are Building For

Commodity Cloud is initially intended for users who have capable but unused or underutilized hardware and want to turn it into useful infrastructure without requiring deep systems-administration expertise.

The initial focus should be on users who value:

* getting more value from hardware they already own
* reducing unnecessary hardware purchases
* simple self-hosting
* practical reuse of existing devices
* automation over manual configuration
* visibility into what their hardware can do

Detailed personas and user segments will be defined separately in the Product Personas document.

---

## 6. Two Product Entry Points

Commodity Cloud should support two complementary ways of thinking.

### 6.1 Hardware-first

The user starts with a device.

> **"What can I do with what I have?"**

Commodity Cloud:

```text
Device
  ↓
Inspection
  ↓
Capabilities
  ↓
Suitable workloads
  ↓
Recommendation
  ↓
Deployment
```

---

### 6.2 Intent-first

The user starts with a goal.

> **"What do I need, and can my existing hardware provide it?"**

Commodity Cloud:

```text
User goal
  ↓
Requirements
  ↓
Available devices
  ↓
Capability matching
  ↓
Recommendation
  ↓
Deployment
```

The long-term product should support both directions.

Users ultimately care more about **what they want to accomplish** than the technical specifications of their hardware.

---

## 7. The Product Model

Commodity Cloud should avoid treating every device as a unique technical problem.

Instead, it should create a common model:

```text
Device
  ↓
Capabilities
  ↓
Constraints
  ↓
Workload
  ↓
Infrastructure
```

For example, an Android phone, an old laptop, and a Raspberry Pi may be completely different pieces of hardware.

Commodity Cloud should nevertheless be able to reason about them using a common language of:

* capabilities
* resources
* constraints
* connectivity
* workloads
* requirements
* suitability

This allows heterogeneous commodity hardware to become part of one understandable system.

---

## 8. Workloads as Product Building Blocks

Workloads are one of the core building blocks through which Commodity Cloud delivers user value.

Commodity Cloud should not exist merely to control devices.

The purpose of managing a device is to make it useful.

A workload represents a useful function that can be deployed onto available infrastructure.

Examples may include:

* file synchronization
* backup
* media services
* network services
* monitoring
* ad blocking
* photo display
* development services
* local storage
* other lightweight infrastructure services

The workload catalogue should grow over time based on:

1. real user needs
2. hardware capabilities
3. workload requirements
4. reliability
5. security
6. ease of deployment
7. maintainability

A workload should not be supported simply because it is technically possible.

It should be supported because it provides meaningful user value.

---

## 9. User Experience Principle

Users should interact primarily with **outcomes**, not implementation details.

Instead of:

```text
Install container runtime
        ↓
Configure container
        ↓
Configure networking
        ↓
Configure service
        ↓
Configure monitoring
```

the experience should move toward:

> **"I want this service."**

Commodity Cloud should determine the technical steps required to make that happen.

Technical details should remain available for advanced users, troubleshooting, and transparency, but they should not be a prerequisite for basic use.

---

## 10. Trust and Transparency

Commodity Cloud may make decisions about a user's hardware and potentially modify devices.

Therefore, automation must not become a black box.

Users should be able to understand:

* what device was detected
* what capabilities were identified
* why a workload was recommended
* what requirements the workload has
* what changes will be made
* what permissions are required
* what risks or limitations exist
* what is currently running
* how to stop or remove it

The product should prefer:

> **Explain → Confirm → Execute**

over silent automation when an action is consequential.

---

## 11. Product Principles

### 11.1 Use What Already Exists

Prefer existing commodity hardware before requiring users to purchase new infrastructure.

### 11.2 Useful Over Technically Impressive

A technically interesting capability is not automatically a useful product feature.

### 11.3 Simplicity Over Configuration

Hide unnecessary infrastructure complexity from users.

### 11.4 Hardware Reality Over Theoretical Capability

Recommendations must consider real-world constraints such as:

* performance
* thermals
* storage
* battery
* connectivity
* reliability
* operating system limitations
* power consumption
* security

### 11.5 Recommend Conservatively

A device being technically capable of running something does not mean it should.

Commodity Cloud should distinguish between:

* **Can Run**
* **Suitable**
* **Recommended**

### 11.6 Automation Should Be Earned

Automation should be based on real experiments and validated behavior.

A documented architecture is not evidence that something works.

### 11.7 Human Control Remains Important

Users should be able to inspect, approve, stop, remove, and recover from deployments.

### 11.8 Open and Extensible

Commodity Cloud should make it possible to add new:

* device types
* capabilities
* workloads
* deployment mechanisms
* integrations

without redesigning the entire product.

---

## 12. Initial Product Scope

The first version should remain deliberately narrow.

The immediate objective is not to support every device or every workload.

The initial objective is to prove the complete product loop:

```text
Discover
   ↓
Inspect
   ↓
Understand
   ↓
Recommend
   ↓
Deploy
   ↓
Verify
```

A successful early implementation should demonstrate that Commodity Cloud can take at least one real commodity device and turn it into a genuinely useful piece of infrastructure through a reproducible workflow.

The existing project already demonstrates real workloads on commodity devices, including a Samsung Galaxy Tab used as a photo frame and a rooted OnePlus 6T running Pi-hole. The current roadmap is working toward automated discovery and inspection before broader planner, installer, dashboard, and intelligence capabilities.

---

## 13. Product Outcome

The desired product outcome is to reduce the distance between:

> **Unused hardware**

and

> **Useful infrastructure**

Commodity Cloud should make this transition increasingly simple, understandable, and repeatable.

The ultimate experience should be:

```text
What I Have
     +
What I Want
     ↓
Commodity Cloud
     ↓
What Is Possible
     ↓
What Is Recommended
     ↓
Make It Happen
     ↓
Keep It Useful
```

---

## 14. Long-Term Direction

The initial product may focus on a small number of devices and workloads.

The long-term vision is broader.

Commodity Cloud should evolve toward a system that can reason across:

```text
Multiple Devices
       +
Multiple Capabilities
       +
Multiple Workloads
       +
User Intent
       +
Constraints
       ↓
Recommended Infrastructure Plan
```

Eventually, a user could describe an outcome rather than a technical deployment.

For example:

> **"I want the important photos in my house backed up."**

Commodity Cloud could understand the requirement, inspect available hardware, identify suitable infrastructure, explain the proposed setup, and help deploy it.

The product therefore moves progressively from:

**Device management**

to

**Infrastructure planning**

to

**Intent-driven infrastructure.**

---

## 15. What Commodity Cloud Is Not

Commodity Cloud is not primarily:

* a replacement for AWS, Azure, or Google Cloud
* a traditional VPS provider
* a Kubernetes distribution
* a hardware marketplace
* a single application such as Nextcloud

Applications such as Nextcloud, Syncthing, Jellyfin, Pi-hole, or WireGuard may become **workloads that Commodity Cloud helps users deploy**.

Commodity Cloud is the layer that helps answer:

> **What can this hardware become, and how can I make it useful?**

---

## 16. Product and Engineering Relationship

This document defines the **product intent**, not the implementation.

Product documentation should primarily define:

* who we are building for
* what problem we are solving
* what outcome the user wants
* what the product should enable
* what constitutes a good user experience
* what should be prioritised

Engineering documentation should define:

* architecture
* implementation
* protocols
* infrastructure
* technical constraints
* engineering decisions
* experiments
* deployment mechanisms

The two should meet at clearly defined product requirements and acceptance criteria.

```text
PRODUCT
Problem
  ↓
User
  ↓
Intent
  ↓
Requirement
  ↓
Acceptance Criteria
        │
        ▼
ENGINEERING
Architecture
  ↓
Implementation
  ↓
Experiment
  ↓
Working Capability
```

This separation allows Product and Engineering to contribute independently while remaining aligned on the same outcome.

---

## 17. Product North Star

### North Star

> **Useful infrastructure from hardware you already own.**

### Product Question

For every major product decision, ask:

> **Does this make it easier for someone to turn existing hardware into something useful?**

If the answer is no, the feature should require a strong justification to belong in the core Commodity Cloud experience.

---

## 18. Document Status

This is a living product document.

As Commodity Cloud evolves, the vision should remain relatively stable while the following may change:

* target users
* supported workloads
* product priorities
* MVP scope
* user journeys
* business model
* technical implementation

Changes to the core vision should be deliberate and explicitly discussed by the project owners.
