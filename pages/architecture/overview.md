---
title: Platform overview
description: The SCBX enterprise AI agent platform, built on Microsoft Foundry and an AI Gateway (Azure API Management).
---

The SCBX AI agent platform lets DataX and the portfolio companies (PortCos) build, run and govern AI agents on Microsoft Foundry, with an AI Gateway built on Azure API Management (APIM) in front of every agent, model and tool.

DataX builds the platform once and deploys the same **tenant stamp** to every PortCo from code. Each PortCo (for example SCBX, AutoX and CardX) gets its own Entra tenant, subscriptions and network spoke.

## The platform at a glance

The platform has four parts.

| Part | Owner | What it does |
|---|---|---|
| **1. Build and release** | DataX | Agent Builder (Copilot Studio), Microsoft Agent Framework templates, SDK packages, a skill registry, and one shared agent deployment pipeline reused by every portfolio |
| **2. Portfolio tenant stamp** | Deployed per tenant from IaC | Developer portal, AI Gateway, Microsoft Foundry, trust and quality controls, and the stamp foundation (network, identity, keys, logs) |
| **3. Operate and govern** | DataX and the PortCo | Operation control plane, agent RBAC, monitoring, drift detection, audit logging, threat protection, FinOps and kill switches |
| **4. Multi-tenant deployment** | DataX | The same stamp in every portfolio tenant, plus an enterprise control plane across tenants |

## Request path

Consumers reach agents, models and tools only through the AI Gateway:

- **Developers** discover APIs, onboard and subscribe through the developer portal (API Center and the APIM Developer Portal).
- **Business users** reach agents through M365 Copilot, Teams and web channels.
- **Business applications** call agents from line-of-business systems.

The AI Gateway publishes four APIs:

| API | Purpose |
|---|---|
| Agents API | Published agents (A2A and Responses) |
| Models API | Common models, token limits and PTU spill-over |
| Tools & MCP API | Approved tools and MCP servers |
| Partner agents API | Outbound, gateway-to-gateway calls to other PortCos' agents |

Gateway policies apply to every call: token rate limits, semantic caching, load balancing and PTU spill-over, circuit breaker, token metrics for FinOps, the kill switch, and A2A and MCP policies.

## Inside the tenant stamp

![Zone connectivity](/images/architecture/zone-connectivity.png)

**Microsoft Foundry**
- One Foundry account per production workload. Non-production shares one account, with a project per use case. Public network access is disabled.
- Agent Service runs prompt agents, workflows and hosted agents. Each agent has an Entra Agent ID and an owner group.
- The IQ layer (Foundry IQ, Fabric IQ and Work IQ) and tools (MCP servers, OpenAPI and Logic Apps) give agents knowledge and actions.
- **Admin-connected models** are a shared pool reached through the AI Gateway. **Workload-specific models** are deployed in the account only when fine-tuned or used by a single use case. An Azure Policy allow-list controls which models are approved.

**Trust and quality**
- Azure AI Content Safety: Prompt Shields, groundedness and PII detection.
- Evaluation: the Evaluation SDK and the AI red-teaming agent.
- Continuous evaluation: live-traffic scoring and drift signals.
- Tracing: OpenTelemetry GenAI traces to Application Insights.

**Stamp foundation** (private by default)
- A spoke VNet with agent subnet injection, private endpoints and private DNS.
- Key Vault, a private Container Registry for agent images, and managed identities with no stored secrets.
- Cosmos DB (threads), AI Search (vectors) and Storage (files) as bring-your-own agent resources.
- Log Analytics through diagnostic settings, and a runner subnet for self-hosted CI/CD runners.

## Build and deploy

Every portfolio has its own pipeline, but all of them reuse one shared agent deployment pipeline:

1. **Build and scan:** container build, SAST and secret scanning.
2. **Push image** to the private Azure Container Registry.
3. **Evaluation gate:** Evaluation SDK, red-teaming and thresholds.
4. **Deploy agent and model:** hosted agent and model, with versions pinned.
5. **Register** the agent in the catalog with its owner group.

Infrastructure is defined in Terraform, so the same stamp is deployed to every tenant with policy as code and drift detection. Self-hosted runners in each tenant spoke reach ACR, Key Vault and Foundry privately, using OIDC with no secrets.

## Enterprise control plane

Across tenants, DataX uses:

- **Agent 365 / API Center** as the enterprise agent registry and admin.
- **Azure Lighthouse** for delegated cross-tenant operations.
- **Azure Policy and management groups** to apply the same guardrails as code in every tenant.
- **Central Log Analytics** for audit and FinOps roll-up across tenants.

:::caution
Cross-PortCo agent calls always go gateway to gateway, over Private Link or a WAF partner endpoint, with one correlation ID. There is no direct agent or network path between PortCos. See [Communication flows](/architecture/communication-flows).
:::
