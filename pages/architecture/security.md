---
title: Security and safety
description: Runtime safeguards for PII and harmful content, keeping personal data out of telemetry, and the package supply chain.
---

## Runtime safeguards on every call

![PII and content safety controls](/images/architecture/pii-content-safety.png)

| # | Control | Where | What it does |
|---|---|---|---|
| 1 | **Content Safety and Prompt Shields** | AI Gateway | Blocks harmful content (hate, sexual, violence, self-harm) and prompt-injection attacks on prompts, responses, MCP tools and A2A calls. Does not mask PII. |
| 2 | **PII redaction** (Azure AI Language) | AI Gateway, optional per use case | Masks personal data before it reaches agents, models or tools, as `[PERSON_1]`, `****` or fake values. Thai is supported. |
| 3 | **Foundry guardrails on the agent** | Agent | Checks user input, tool calls, tool responses and output for harm, prompt attacks, protected material and PII. Overrides the model's guardrail. |
| 4 | **Foundry guardrail on the model** | Model | The same controls on direct model calls, including a PII filter on output that flags or blocks per category (email, phone, card, bank account, national ID). It cannot mask. |
| 5 | **Outbound PII redaction** (Azure AI Language) | AI Gateway | The same redaction on payloads sent to external tools and partner PortCos. |

## Keeping PII out of logs and traces

- **AI Gateway logs:** body logging is off for AI APIs. Headers and query strings are masked. Only metadata is logged: caller, route, status and token counts. APIM does not support body masking.
- **Foundry traces:** prompts and responses are kept only in the `AppGenAIContent` table, which is set to Protected. Read access needs the Privileged Monitoring Data Reader role, through PIM.
- **Client-side tracing:** content recording stays off (the default) in production. Do not propagate baggage that may carry personal data.
- **Application code:** a span processor masks or drops sensitive attributes before telemetry is sent to Application Insights.
- **Copy to ELK:** only metadata is copied from Application Insights through Event Hubs. Prompts and responses stay in `AppGenAIContent` and are not exported.

## Agent identity and access

- Each agent gets its own Entra Agent ID from a blueprint for its trust tier.
- Permissions are least privilege at the narrowest resource scope, with on-behalf-of (OBO) access for user data.
- A2A and MCP endpoints are allow-listed and re-authorized at every hop.
- Production has no standing human access. Break-glass access goes through PIM.

## Kill switches

There are six levels of stop, each with two-person approval through a Logic Apps runbook:

1. Application feature flag (Azure App Configuration)
2. Model
3. Provider
4. All AI traffic: APIM returns 503
5. Network block (Azure Firewall / NSG)
6. Identity revocation (Entra ID)

## Package supply chain

Every package reaches developers through one approved **Azure Artifacts** feed. New packages are checked before they are approved.

- **Developers and pipelines** install packages from the feed only, with read access.
- **The feed** holds approved packages only (a `@Release` view), and internal package names are protected.
- **The intake pipeline** is the gate: a developer requests a package, automated checks run, and it is approved automatically or by a reviewer.
- **Direct downloads** from public registries (npm, PyPI, NuGet, Maven, crates.io) are blocked by Azure Firewall.
- **Container images** come from Azure Container Registry and are scanned by Defender.
- **Models** come from the Foundry model catalog only.
- **Every build** runs a dependency scan and produces an SBOM.
