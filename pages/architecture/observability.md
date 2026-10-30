---
title: Observability
description: Options for collecting and viewing platform telemetry, how Application Insights data reaches ELK, and federated observability across PortCos.
---

## Four options

Each option trades Foundry's built-in agent observability against using SCB's existing Kafka and ELK standard.

![Observability options](/images/architecture/observability-options.png)

| Option | Flow | Keeps | Misses |
|---|---|---|---|
| **1. Azure-native** | App Insights → Log Analytics → Azure Monitor | Foundry trace view, agent dashboard and evaluation; Sentinel and Defender on the same workspace; no extra components | Not SCB's ELK standard; needs KQL and Azure Monitor skills; Log Analytics ingestion is billed per GB |
| **2. Azure store, Grafana view** | App Insights + Log Analytics → Grafana | Same Foundry features as option 1; logs, traces, metrics and alerts in Grafana; queries in place with nothing copied | No Azure Monitor alerts or workbooks; a Grafana instance to run and secure privately; KQL rather than Kibana-style search |
| **3. App Insights, viewed in ELK** | App Insights → Event Hubs → SCB Kafka → Elasticsearch and Kibana | Ops teams stay in Kibana and SCB's Kafka; the Foundry portal still works | Data stored twice; an export pipeline to run; prompts and responses stay in App Insights only; export delay |
| **4. ELK only** | OpenTelemetry Collector → SCB Kafka → ELK | One pipeline following the SCB pattern; full control of content and masking | No tracing for prompt agents and workflows; no Foundry trace view, dashboard or evaluation; agents must be hosted (code) agents; Event Hubs still needed for platform logs |

## Application Insights to ELK

Application Insights cannot push to Logstash or Elasticsearch directly. A diagnostic setting streams the `App*` tables to a DataX-owned Event Hubs namespace (Standard tier, Kafka endpoint on port 9093, private endpoint for readers). From there, one of three routes reads it into the common ELK:

| Route | How | When to use |
|---|---|---|
| **A. Logstash Kafka input** (recommended) | Logstash reads the Event Hubs Kafka endpoint (SASL_SSL :9093), splits the `records` array, masks fields and routes to the `datax-*` index | Default: the simplest option, using the ELK team's existing Logstash |
| **B. Strimzi MirrorMaker 2** | Event Hubs topics are mirrored into SCB's Strimzi Kafka, then into the existing Logstash pipeline unchanged | When every source must enter through SCB's own Kafka |
| **C. Elastic Agent** | Elastic Agent's Azure Event Hub input reads straight into Elasticsearch, with a storage container for checkpoints | When no Logstash processing is needed |

An alternative tap is a Log Analytics data export rule, which also exports PaaS tables and can filter with transformations, but is charged per GB.

![Application Insights to ELK integration routes](/images/architecture/appinsights-to-elk.png)

## Federated observability across PortCos

Each PortCo publishes its telemetry and DataX views it centrally.

![Federated observability](/images/architecture/federated-observability.png)

1. **In each PortCo**, every resource (App Insights, APIM, Foundry, Key Vault, AI Search, Cosmos DB) and the subscription activity log send diagnostic logs to the PortCo's own Event Hubs namespace. Azure Policy deploys the diagnostic settings.
2. **DataX** reads each PortCo's Event Hubs with listen-only access into SCB Strimzi Kafka, with one topic and one consumer group per PortCo.
3. **Logstash** splits Azure Monitor records, masks remaining personal fields, adds `portco`, `app` and `environment`, and maps everything to one schema: correlation ID, agent, model, tokens and latency.
4. **Elasticsearch** keeps an index per PortCo (`scbx-*`, `autox-*`, `cardx-*`). Kibana offers a group view for DataX, a PortCo view limited to its own index through Entra ID groups, governance views (compliance, drift and cost per PortCo) and security alerts to SCB's SOC.

:::note
Prompts and responses never leave the PortCo. Retention and chargeback are set per PortCo.
:::
