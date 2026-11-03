---
title: Policy and IaC governance
description: How Platform publishes a governed baseline, PortCos deploy it, and evidence flows back.
---

Platform publishes the baseline, PortCos deploy it, and compliance and drift evidence flow back to Platform.

## Platform governance plane

Platform runs the governance plane from its own tenant and engineering organization:

- **Standards and control catalogue:** approved models and Responsible AI; identity, network and data handling; monitoring and remediation rules.
- **Authoritative Git repository:** hardened Terraform modules, Azure Policy initiatives (the baseline), APIM policy fragments and Foundry guardrail baselines.
- **Tested, approved releases:** protected branches and reviewer approval, versioned modules with a release manifest, and an upgrade deadline for each release.
- **Group assurance and exceptions:** compliance and adoption per PortCo, a drift register with owners and SLAs, and time-bound exemptions that only Platform can grant.

## In each PortCo

Each PortCo (PortCo 1, PortCo 2, PortCo 3 and so on) has its own Entra tenant and subscriptions.

- **Deployment repository and CI/CD:** pulls the approved release read-only and sets local parameters only. Uses workload identity federation (OIDC) and isolated state. A nightly `terraform plan` reports drift.
- **Local enforcement:** the Platform baseline initiative is assigned, unchanged, at the PortCo root management group. A PortCo may add stricter policies, never weaker ones. CI/CD checks and runtime AI controls apply.
- **AI Gateway and Foundry landing zones:** the PortCo owns the local request path and operations, built on its existing Azure landing zone.

## DevSecOps pipeline

Infrastructure changes go through **Validate → Plan → Approve → Apply**, with OIDC sign-in, separate identities for plan and apply, and the existing secure-SDLC scans reused.
