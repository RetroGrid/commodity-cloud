# Commodity Cloud Engineering Principles

These principles guide the design of every workload, script and service within Commodity Cloud.

## 1. Experiment before abstraction

Every abstraction must be earned through at least one working implementation.

## 2. Leave the system unchanged

Temporary configuration changes must be reversible.

If a script opens a firewall rule, it should restore it.

If it starts a service, it should provide a way to stop it.

## 3. Detect, don't assume

Prefer runtime capability detection over platform assumptions.

## 4. Fail early

Errors should explain what happened and how to recover.

## 5. Design for constrained hardware

Older devices are first-class citizens.

Memory, CPU and storage are considered limited resources.

## 6. Build composable workloads

Every workload should solve one problem well.

Integration happens at the Commodity Cloud layer.

## 7. Automate only after manual validation

Every automated workflow should first be proven manually.

Automation codifies knowledge—it should not replace understanding.

## 8. Prefer local-first

Nodes should function without requiring Internet connectivity whenever possible.

## 9. Security is part of automation

Automation should not permanently weaken the host.

## 10. Documentation is part of the implementation

Experiments, failures and decisions are captured alongside the code.
