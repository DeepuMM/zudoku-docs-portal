---
title: Communication flows
description: How applications, agents, models and tools talk to each other, within one PortCo and across PortCos.
---

Anything shared across Foundry accounts or PortCos goes through the AI Gateway. Agents inside one Foundry account talk to each other directly. Every call is traced centrally.

![All flows, simplified](/images/architecture/access-flow-simplified.png)

## Flows within one PortCo

| Flow | Path |
|---|---|
| **Model calls** | Agent → admin-connected model → APIM Models API → shared model deployment |
| **Agent consumption** | Business apps, other PortCos or external services → APIM Agents API (by subscription) → published agent |
| **Tools and MCP** | Agent → APIM Tools & MCP API → approved tool or MCP server |
| **Inside one Foundry account** | Agents call each other directly, with no gateway hop |
| **Telemetry** | The gateway, Foundry accounts and agents send traces, logs and token usage to central monitoring |

Admin-connected models are reached as `ai-gateway/<model>` using the project's managed identity. Workload-specific models (fine-tuned or single use case) are called directly inside the account.

A published agent is registered in APIM and API Center so others can find it and subscribe.

![Agent and model access flow, one PortCo](/images/architecture/access-flow-one-portco.png)

### Tool calls

Agents reach both internal and external tools through the Tools & MCP API. External tool calls leave through the Azure Firewall with an FQDN allow-list.

![Tool call flow](/images/architecture/access-flow-tool-calls.png)

## Cross-PortCo agent communication

Each PortCo runs its own AI Gateway and Foundry landing zones in its own Entra tenant. An agent in one PortCo reaches an agent in another **only through both AI Gateways**.

![Cross-PortCo agent communication](/images/architecture/access-flow-cross-portco.png)

### Rules

1. Cross-PortCo calls always go caller gateway → provider gateway. Agents never call another PortCo's agent directly.
2. The provider PortCo publishes the agent in its APIM and API Center, and approves each consuming PortCo's subscription.
3. The caller PortCo registers the partner agent as an outbound API (Partner agents API) in its own gateway, so its token budget, logging and kill switch apply.
4. Inside one Foundry account, agents call each other directly. Calls across accounts in the same PortCo go through that PortCo's gateway.

### How the cross-tenant call works

- **Connectivity:** a private endpoint to the provider's APIM (manually approved), or a partner endpoint behind a WAF.
- **Identity:** an Entra multi-tenant app or federated credential, plus an APIM product subscription.
- **Control:** the provider has a kill switch per consumer.
- **Tracing:** one correlation ID (W3C `traceparent`) passes through both gateways, so the call is traced end to end in both PortCos' Application Insights, gateway logs, Agent 365 and the DataX central SOC.

## Step by step

![Communication flows step by step](/images/architecture/communication-flows.png)

**1. External application** (Internet → DMZ secured hub → AI Gateway → Foundry agent)
1. Get a token from Entra ID (app registration).
2. Call over HTTPS (TLS 1.2); the WAF inspects the request.
3. Azure Firewall routes the call to the PortCo spoke.
4. APIM checks the JWT, subscription, rate and token limits.
5. APIM calls the agent over a private endpoint.
6. The agent uses models and tools, also through APIM.

**2. Internal application** (existing app → secured hub → AI Gateway → Foundry agent)
1. Authenticate with a managed identity or user token.
2. Call privately through the hub firewall.
3. APIM applies policies and routes to the agent.
4. The agent responds, and usage is logged for chargeback.

**3. PortCo A to PortCo B**
1. Agent A calls its own APIM (Partner agents API).
2. APIM A applies budget, logging and the kill switch.
3. The call goes through the hub to APIM B with a cross-tenant token.
4. APIM B validates it and calls Agent B.
5. Agent B responds on the same path.

**Applies to all flows:** one correlation ID end to end; traces in Application Insights; WAF, firewall and APIM logs; token and rate limits per consumer; usage per app and PortCo for chargeback; audited policy decisions; and a kill switch per consumer.
