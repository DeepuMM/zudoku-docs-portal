---
title: Agent monitoring and drift
description: Capability #13. Checking that an agent in production still behaves like the version that was tested and approved.
---

The goal is to check that an agent in production still behaves like the version that was tested and approved.

## What we collect and where it is kept

- **AI agents:** a record of every run, including steps, tools called, timing and errors.
- **AI Gateway:** tokens, response time and throttling per PortCo.
- **Safety alerts:** harmful content blocked, prompt attacks detected and Defender for AI alerts.

All agent activity, including the questions and answers, is recorded in **Application Insights**. Questions and answers stay there; only numbers and scores leave.

The **approved baseline** holds the scores and behaviour recorded when this agent version was tested and approved (capabilities #5 and #16).

## Four monitoring checks

| Check | Can we do it? | What it is | How we build it |
|---|---|---|---|
| **1. Operational health** | Yes | Reliability, latency, throughput and cost against the approved baseline | App Insights and APIM metrics; alert rules on error rate, p95 latency, 429 rate and tokens per request; dashboards in Kibana |
| **2. Behavioural drift** | Yes, with build work | Compares how the agent works (tool mix, steps per run, loops, retries, hand-offs to a person) with the baseline | OpenTelemetry agent spans per conversation; a scheduled query computes statistics per agent version |
| **3. Quality regression** | Partly | Scores a sample of real answers and compares them with the scores the version got at approval | Foundry continuous evaluation on 1–5% of traffic with fixed evaluators, such as task adherence, intent resolution and tool call accuracy |
| **4. Adversarial robustness** | Partly | Checks the deployed version still resists prompt injection and jailbreaks | Scheduled red-team runs (Foundry AI Red Teaming Agent, preview) monthly and on every change; findings go to the security team |

## Who sees the results

- **Dashboards (Kibana):** numbers and scores per PortCo. Questions and answers are not copied here.
- **Agent owner:** alerted when results stay worse than the approved baseline, not for one bad answer.
- **Security team (SOC):** safety alerts go straight to the SOC, and security findings are kept there.

## Feasibility

| What #13 asks for | Can we do it? | Why |
|---|---|---|
| Reliability and speed | Yes | Standard monitoring data; only the comparison with the baseline needs setting up |
| Answer quality vs the approved version | Partly | Only a sample of answers, scored by AI. Useful as a warning sign, not proof |
| Robustness | Partly | Needs scheduled attack tests. Foundry red teaming is not yet rolled out in Southeast Asia, so local tooling is used until then |
| Tools used, steps, loops, retries | Yes | The data is in the traces; we write the queries and dashboards |
| Near misses and hand-offs to a person | Not yet | Agents must first log these as agreed events |
| Behaviour change with no rule broken | Partly | Works for busy agents; quiet agents don't produce enough data |
| Security findings kept by the security team | Yes | Safety alerts already flow to the security team |

## Things to know

- In live use there is no "right answer" to check against, so answer quality is an estimate from AI scoring.
- Fix the version of the model that does the scoring, or the scores will change on their own.
