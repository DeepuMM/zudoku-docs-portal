---
title: Consumption patterns
description: Three ways DataX and the PortCos can host and consume the platform, and how to choose between them.
---

The **AI zone** is the AI Gateway landing zone plus the Foundry landing zone. The three patterns differ in who hosts the AI zone, and how much of it each PortCo gets to itself.

All three share the same controls: governed gateway access, separate non-prod and prod landing zones, controlled workload promotion, centrally defined baseline standards and auditable ownership. Hosting, isolation, deployment and operations differ.

## The three patterns

| | Pattern 1: DataX-hosted managed service | Pattern 2: DataX-hosted shared Foundry account | Pattern 3: PortCo-owned, DataX-governed |
|---|---|---|---|
| **In one line** | One shared APIM with a product and policy scope per PortCo, plus a separate Foundry boundary per PortCo | One gateway and two shared Foundry accounts (non-prod and prod); each PortCo gets a project in each | Each PortCo owns its gateway and Foundry landing zones; DataX publishes the baseline and receives evidence |
| **Where it runs** | DataX subscriptions | DataX subscriptions | PortCo subscriptions, PortCo tenant |
| **AI gateway** | Two DataX APIMs (non-prod and prod), a product per PortCo in each | Same as Pattern 1 | Non-prod and prod APIM per PortCo, deployed from the DataX baseline |
| **Foundry account** | Two per PortCo (non-prod and prod), each in its own subscription | Two, shared; one project per PortCo in each | The PortCo's own |
| **Isolation between PortCos** | Separate account, models and network; shared gateway | Project only; models, quota and network are shared | Separate tenant and subscription |
| **Developer access (dev)** | Azure AI User on the PortCo's dev project | Same | Same |
| **App access (prod)** | Through the AI gateway only; no human access to prod projects | Same | Same |
| **Agent deployment** | Separate PortCo workload pipeline using the DataX template | Same as Pattern 1 | PortCo-run pipeline from the DataX template |
| **Who pays** | DataX, charged back per product and landing zone | DataX, split by usage per project | The PortCo, directly |
| **How DataX governs** | Owns and runs everything | Owns and runs everything | Publishes baseline and policy; PortCo runs and remediates; DataX receives compliance, drift and aggregate reporting |
| **Best fit** | PortCos wanting a managed service with their own Foundry boundary | Early adoption and low-risk use cases at the lowest cost | Regulated PortCos that must keep data and cost in their own tenant |

Patterns can be combined. A common deployment contract and agent packaging standard reduce migration effort, but identity, endpoints, network, data, quota, policy, telemetry and ownership still need to be reconfigured when moving between patterns.

## Choosing a pattern

1. **Must data, cost and identity stay in the PortCo's own tenant?** Yes → **Pattern 3**.
2. **Does it need its own boundary**, such as its own key, network rules, region or PTU, or does a regulator require one? Yes → **Pattern 1**.
3. **Small hosted-agent footprint and few projects?** Yes → **Pattern 2**. No → Pattern 1, or a second shared account.

### Can a PortCo share a Foundry account?

Share an account only when **all** of the left column apply. Give it its own account when **any** of the right column applies.

| Question | Share when | Own account when |
|---|---|---|
| Data and regulator | Logical isolation per project is accepted | A regulator or data classification needs its own account |
| Encryption and settings | Shared keys, one network configuration and one region are fine | Needs its own customer-managed key, network rules, region or Defender settings |
| Hosted agent load | Small, steady peak | Large or spiky peak that could exhaust the shared subnet or session quota |
| Model throughput | Standard deployments; a per-PortCo deployment limit is enough | Needs guaranteed throughput (PTU) or its own quota pool |
| Network egress | The same tool and back-end reach is acceptable from one agent subnet | The firewall must tell this PortCo's agent traffic apart |
| Projects | The account stays well under ~25 busy projects | Many projects, or many busy ones |
| Cost | Chargeback by usage per project is acceptable | Needs its own bill |
| Blast radius | Can tolerate shared maintenance and incidents | Critical production that must not be affected by other PortCos |

## What DataX must do when it hosts Foundry

For Patterns 1 and 2:

- **Capacity:** a dedicated DataX subscription per PortCo landing zone (Pattern 1) or per shared account (Pattern 2), to separate model and session quota. Use a /22 or larger agent subnet for a shared account and plan to 80%. Request session and model quota before go-live. Plan Cosmos DB at 5 × 1,000 RU/s per project.
- **Isolation:** one model deployment per PortCo (rate limits are per deployment), an APIM product per PortCo with token limits, PortCo groups only on their own projects, and no connections shared across PortCos' projects.
- **Identity and access:** PortCo developers join as B2B guests on their dev project only. APIM accepts tokens from PortCo tenants. Prod has no human access; break-glass goes through PIM.
- **Network:** the DataX spoke sits on the group vWAN hub, with firewall rules per PortCo source range, private DNS resolvable from every PortCo, and a return path for agent tool calls into PortCos.
- **Operations:** alert on 429s (`session_quota_exceeded`, `subnet_exhausted`, model rate limits), watch data-proxy 5xx errors (there is no subnet usage metric), track quota with the Usages API, and review capacity monthly.
- **Commercials:** usage per APIM product and project, monthly chargeback to each PortCo, and agreed SLAs and support per PortCo.

## Limits of one shared account

Worked example: 10 PortCos share the prod Foundry account in Southeast Asia, with a /22 agent subnet and one prod project each.

| Limit | Rule | In this example |
|---|---|---|
| Concurrent hosted sessions | Lowest of the session quota and 80% of subnet IPs (1 IP per session) | min(2,000, ~800) ≈ 800, about 80 per PortCo |
| Session quota | Per subscription and region, shared by every account in it | 2,000, also used by any other account in the subscription |
| Projects | ~250 at low traffic, ~25 under heavy session load | 20 projects: fine at low traffic, at the edge under heavy load |
| Cosmos DB | Projects × 5 × 1,000 RU/s (Responses API) | 20 × 5,000 = 100,000 RU/s |
| Model quota | One pool per model per subscription | Split across 10 deployments, one per PortCo |
| Usage tier | Monthly tokens per model, per tenant | All PortCos' tokens count against DataX's tier |

:::tip
Split when any limit gets tight: add a second shared account with its own subnet and Cosmos DB, or move the heaviest PortCo to its own Foundry account. Quota increases take time to approve, so review capacity monthly.
:::

These thresholds are planning guidance based on Microsoft Learn (Agent Service quotas and limits, Agent Service networking, standard agent setup, Azure OpenAI quotas), not service guarantees.
