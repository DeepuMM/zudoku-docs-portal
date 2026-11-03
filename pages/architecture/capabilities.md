---
title: Capabilities
description: How the platform delivers each of its capabilities, and the technology it uses.
---

Each capability is mapped to how the AI Platform Design (Draft v0.2, 01/10/2026) achieves it and the technology it uses. The phase comes from section 2 of the design document.

| # | Capability | Phase | How it is achieved | Technology |
|---|---|---|---|---|
| 1 | SDK Management | 2 | Private, versioned SDK feeds with package pipelines and release governance. The SDK adds identity, telemetry, retries and fallback to every call made through the gateway. | Azure Artifacts / GitHub Packages |
| 2 | Monitoring Framework | 1 | Collects metrics, logs and traces from the gateway, Foundry, models and supporting resources, correlates them with common IDs and raises alerts. Plugs into the existing central monitoring and PortCo dashboards. | Azure Monitor, Log Analytics, Application Insights, Foundry observability, Diagnostic Settings, Action Groups, Grafana |
| 3 | Operation Control Plane | 2 | One administrative view across agents and services: registry, identity, policy and health. | Agent 365 (preferred); fallback: APIM Developer Portal + Entra Agent ID + Azure Policy + Azure Monitor |
| 4 | FinOps & CostOps | 2 | Budgets, tags and token usage per team and use case, with chargeback. A custom chargeback layer is needed. | Azure Cost Management, APIM token metrics, Foundry usage in Log Analytics |
| 5 | PromptOps | 2 | Prompts are versioned, governed, evaluated and can be rolled back. See [PromptOps](/architecture/promptops). | Third-party solution (to be selected) |
| 6 | Audit Logging | 1 | Diagnostic settings send activity, resource, Entra ID and application logs to separate Operations, Security and Application workspaces. Older records are archived to immutable storage under the set retention periods. | Azure Monitor, Log Analytics, Diagnostic Settings, immutable storage |
| 7 | Agent Registry | 1 | The APIM Developer Portal is the system of record for every agent (prompt, workflow, hosted, external). Each entry has an Entra Agent ID and a mandatory sponsor and owner group, and is filled automatically from Agent 365, Foundry, APIM and the pipeline. Access is requested through APIM product approval. | APIM Developer Portal, Foundry agent inventory, Entra Agent ID / Agent 365 |
| 8 | Model Registry | 1 | The APIM Developer Portal holds every approved model's identity, lifecycle, conditions of use and endpoints, synced from Foundry deployments and APIM. | Foundry model catalog, APIM, APIM Developer Portal |
| 9 | Agent RBAC | 1 | Each agent gets its own identity from a blueprint for its trust tier. Permissions are least privilege at the narrowest resource scope, with on-behalf-of (OBO) access for user data. A2A and MCP endpoints are allow-listed and re-authorized at every hop. | Microsoft Entra ID, Entra Agent ID, Azure RBAC / ABAC, Foundry roles, PIM |
| 10 | Kill Switches | 1 | Six levels of stop: application feature flag, model, provider, all AI traffic (APIM returns 503), network block and identity revocation, with two-person approval. | APIM policies, Azure App Configuration, Azure Firewall / NSG, Entra ID, Foundry controls |
| 11 | DevSecOps | Not phased | A golden baseline of Terraform modules and policy as code, deployed through Validate → Plan → Approve → Apply pipelines. OIDC sign-in, separate plan and apply identities, existing secure-SDLC scans reused. | Terraform, enterprise Git and CI/CD, OIDC workload identity federation, Azure RBAC |
| 12 | Model Hosting & Serving | 1 | Approved models are hosted centrally in each PortCo's AI Gateway landing zone and consumed by agents through APIM, with fallback and load balancing across backends. Dedicated deployments only where a workload needs them. | Foundry Models, Azure OpenAI, AML managed endpoints, APIM backend pools |
| 13 | Agent Telemetry & Drift Detection | 2 | Continuous evaluation of live traffic against the approved baseline, with accuracy, cost and quality alerts. See [Agent monitoring and drift](/architecture/agent-monitoring). | Azure ML drift monitoring, Foundry continuous evaluation, Azure Monitor alerts |
| 14 | Developer Portal | 2 | One front door for documentation, onboarding, discovery and access requests. | APIM Developer Portal |
| 15 | Agentic Framework | 1 (core), 2 (patterns) | Deployed and run by the application team inside its own workload, using only the governed model, tool and identity paths. Reference templates follow in Phase 2. | Microsoft Agent Framework |
| 16 | Agent / LLM Evaluation | 2 | Pre-release evaluation of quality, safety and grounding against approved test cases, as a release gate. | Azure AI Evaluation SDK, Foundry evaluators, AI red-teaming agent |
| 17 | Security & Threat Protection | 1 | Posture management, runtime threat detection, content filtering and prompt-attack detection. Alerts go to Defender XDR and the enterprise SIEM. See [Security and safety](/architecture/security). | Defender for Cloud (CSPM), Defender for AI Services, Azure AI Content Safety, Prompt Shields, Defender XDR |
| 18 | Agent Builder | 2 | Low-code / no-code agent building for citizen developers. | Copilot Studio |
| 19 | API Management | 1 | The single entry point: Entra ID sign-in, policy checks, token limits, quotas, semantic caching, load balancing, content safety and model fallback. Internal-only and zone-redundant. | Azure API Management Premium v2 with AI Gateway policies |
| 20 | MCP Registry | Not phased | The APIM Developer Portal records every MCP server and tool with its schema and whether it reads or writes data. External servers are imported only after review, and access is requested through the APIM portal. | APIM, APIM Developer Portal, Foundry toolbox |
| 21 | Business Process Workflow Orchestration | Not covered | Not addressed in the design document yet. | To be decided |

## Open points

- **Numbering:** the design document numbers Operation Control Plane as 2 and Monitoring Frameworks as 3. `capabilities-and-definitions.md` numbers them the other way round. This table follows `capabilities-and-definitions.md`.
- **Gaps in the design document:**
  - #21 Business Process Workflow Orchestration is not covered.
  - #11 DevSecOps and #20 MCP Registry are described (sections 8.5 and 7.11) but have no phase in section 2.
  - Section 7.12 (Agent Builder) is still a template.
- **PromptOps:** the design document lists a third-party solution, but the PromptOps design proposes Foundry agent versions and skills, with Git and the shared pipeline. One of the two needs to be updated.
