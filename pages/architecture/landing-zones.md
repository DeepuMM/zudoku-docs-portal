---
title: Landing zones
description: The AI Gateway and Foundry landing zones, when to create a Foundry account or a project, and the sandbox deployment.
---

Each PortCo runs two landing zones:

- The **AI Gateway landing zone**: Azure API Management, API Center and the shared model deployments.
- The **Foundry landing zone**: Foundry accounts and projects, where agents run.

Both are built on the existing Azure landing zone and deployed from the same Terraform baseline.

## AI Gateway landing zone (production)

![AI Gateway landing zone, production](/images/architecture/ai-gateway-landing-zone-prod.png)

## Foundry landing zone (production)

## Foundry account or project?

A **Foundry account** is the governance and deployment boundary. A **project** is a workspace for one team or use case, not a substitute for an account. Work through the questions in order:

1. **Does it need a new region, tenant (PortCo), network or CMK policy, owner, data boundary or model-deployment governance?** Yes → create a new **Foundry account**.
2. **Is it a production workload without an approved co-location exception?** Yes → create a **dedicated account**. Every production workload gets one by default.
3. **Does it fit the same operational boundary as the existing projects?** No → create a new **account**. Yes → create a new **project** under the existing account.

The **same operational boundary** means the workload accepts the account's existing:

- environment (dev or prod)
- security settings: network, keys, content filters and admins
- model deployments and version upgrade schedule
- shared connections, such as AI Search or SharePoint

![Foundry account vs project decision tree](/images/architecture/foundry-account-vs-project.png)

### What a project does not isolate

- Model deployments and parent connections are available to every project in the account.
- Account-scope RBAC is inherited, and some Foundry Tools APIs need account access.

### Environments

Prod and non-prod always use separate accounts. Non-prod defaults to one shared account per tier. A dedicated test account is allowed only by approved exception, such as regulated test data or performance mirroring.

A documented exception for **production co-location** needs all of the following: the same regulatory scope, data classification, residency and data handling; the same network boundary, DNS namespace and identity boundary; and every owner accepting the shared outage and quota-exhaustion risk.

## Sandbox deployment

The sandbox is deployed in its own subscription in Southeast Asia (as of 2026-10-08).

| Resource group | VNet | Subnets |
|---|---|---|
| `az-rg-dtx-aiplatform-aigw-dev-001` | `az-vnet-dtx-aiplatform-aigw-dev-001` (10.0.0.0/22) | APIM 10.0.0.0/24 · private endpoints 10.0.1.0/26 · Logic Apps 10.0.1.64/26 · AzureFirewallSubnet 10.0.1.128/26 · DNS resolver inbound 10.0.1.192/28 and outbound 10.0.1.208/28 |
| `az-rg-dtx-aiplatform-foundry-dev-001` | `az-vnet-dtx-aiplatform-foundry-dev-001` (10.0.4.0/22) | Foundry agent 10.0.4.0/24 (delegated to `Microsoft.App/environments`) · Foundry private endpoints 10.0.5.0/26 · build 10.0.5.64/27 |

- Every workload subnet has an NSG and a route table that sends `0.0.0.0/0` to the Azure Firewall (Standard).
- The two VNets are peered. 13 `privatelink.*` private DNS zones are linked to both.
- The Foundry account (`az-aif-dtx-aiplatform-foundry-dev-001`) has public network access disabled and one project, `usecase-001`, with its own user-assigned managed identity and an agent capability host.
- Bring-your-own agent resources (Cosmos DB, Storage, AI Search), Key Vault, Container Registry, Log Analytics and Application Insights are reached over private endpoints.
