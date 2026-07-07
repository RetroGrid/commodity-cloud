# ADR-002: Capability-Driven Infrastructure Composition

**Status:** Proposed

**Date:** 2026-07-07

## Context

Commodity Cloud is designed to reuse existing hardware and compose infrastructure for home labs, edge devices, and small-scale deployments.

Target environments vary significantly:

- Raspberry Pis
- Mini PCs
- NAS devices
- Old laptops/desktops
- Android devices
- Existing Docker hosts
- Existing VPN solutions
- Existing storage solutions

Users may already have software or services that satisfy certain infrastructure requirements.

Examples include:

- VPN providers with DNS filtering and ad blocking
- Existing NAS appliances
- Existing reverse proxies
- Existing monitoring stacks
- Existing authentication providers

Blindly deploying additional services leads to:

- Unnecessary resource consumption
- Increased operational complexity
- Duplicate functionality
- More maintenance
- Higher power usage
- Poor user experience

Commodity Cloud should avoid installing software simply because it is available.

---

## Decision

Commodity Cloud SHALL compose infrastructure based on **required capabilities**, not predetermined software products.

Every service must justify its existence by providing capabilities that are not already available within the user's environment.

Before recommending or installing any component, the planner should evaluate:

1. What capability is required?
2. Does the environment already provide this capability?
3. Is the existing implementation sufficient?
4. If yes, reuse it.
5. If no, recommend or deploy the smallest suitable solution.

---

## Capability First

Commodity Cloud reasons about capabilities such as:

- DNS Filtering
- Ad Blocking
- Local DNS
- VPN
- Remote Access
- Storage
- Backup
- Reverse Proxy
- Container Runtime
- Monitoring
- Logging
- AI Runtime
- Authentication
- Certificate Management

Applications are implementations of those capabilities.

Example:

```
Capability
    ↓
DNS Filtering

Possible Implementations

- Pi-hole
- AdGuard Home
- NordVPN Threat Protection
- Router-based DNS filtering
```

Commodity Cloud should choose an implementation only if the capability is missing.

---

## Example

### User A

Environment:

- NordVPN
- Threat Protection enabled

Requirement:

```
Network-wide ad blocking
```

Evaluation:

```
Capability exists

↓

Do not deploy Pi-hole
```

---

### User B

Environment:

- Standard ISP router
- No VPN
- IoT devices
- Smart TV

Requirement:

```
Network-wide ad blocking
```

Evaluation:

```
Capability missing

↓

Deploy Pi-hole
```

---

### User C

Environment:

- Synology NAS
- SMB Shares
- Scheduled backups

Requirement:

```
Local storage
```

Evaluation:

```
Storage capability already exists

↓

Do not deploy another NAS solution
```

---

## Consequences

### Advantages

- Reduced resource consumption
- Simpler infrastructure
- Better reuse of existing systems
- Lower operational cost
- Lower power consumption
- Easier maintenance
- Better recommendations
- Explainable deployment decisions

### Trade-offs

- Requires environment inspection
- Requires capability detection
- Requires a capability catalogue
- Some capabilities may require user confirmation
- Planner becomes more sophisticated over time

---

## Implementation Roadmap

### Phase 1

Capability detection is primarily rule-based.

Example:

```
NordVPN + Threat Protection

↓

DNS Filtering = Available
```

---

### Phase 2

Capability detection expands through plugins and inspectors.

Examples:

- Docker inspection
- Router inspection
- NAS inspection
- Kubernetes inspection
- Android inspection

---

### Phase 3

An AI planner reasons over the capability graph and proposes the minimum infrastructure necessary to satisfy user goals.

---

## Guiding Principle

Commodity Cloud is not an installer.

Commodity Cloud is an infrastructure architect.

Its responsibility is to recommend and deploy the smallest architecture that satisfies the user's requirements.

Every deployed service must justify its existence.

Complexity must be earned.

---

## Future Considerations

Potential future enhancements include:

- Capability scoring
- Multiple implementation choices
- Cost-aware planning
- Energy-aware planning
- Privacy-aware planning
- Performance-aware planning
- User preference profiles
- AI-assisted architecture optimisation