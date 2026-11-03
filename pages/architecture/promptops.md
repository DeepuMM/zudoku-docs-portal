---
title: PromptOps
description: Capability #5. Every prompt change is versioned, reviewed, tested and reversible.
---

Git is the source of truth and the Platform pipeline is the only identity that writes to Foundry. Agent instructions, skills and toolboxes are released together, and the approved versions and hashes feed drift detection.

## Repository layout

The `agent-config` repository holds:

| Path | Contents |
|---|---|
| `agents/<agent>/agent.yaml` | Model, instructions and toolbox |
| `skills/<skill>/SKILL.md` | Shared guidance |
| `toolboxes/<toolbox>.yaml` | Tools and pinned skill versions |
| `release-manifest.json` | Approved versions and SHA-256 hashes |

## From change to production

1. **Draft:** the change is made on a branch.
2. **Review:** CODEOWNERS approve the pull request. Material changes need extra approvers.
3. **Merge** to `main`.

Then the Platform pipeline runs:

1. **Validate:** lint, policy checks and hash computation.
2. **Deploy to dev:** skills, toolbox and agent versions in the dev project.
3. **Evaluate** (capability #16): results and versions are attached to the release.
4. **Approval gate:** environment approval, one release at a time.
5. **Publish to prod:** create versions, pin them and publish the manifest. People have read-only access to the prod project.

## After release

- **Drift detection** (#2 and #13): running versions are compared with the published manifest.
- **Integrity check:** a scheduled job compares deployed versions and content hashes with the manifest, and alerts on any unauthorised change.
- **Rollback:** redeploy the previous Git tag, or re-pin the earlier agent version. Checks are re-run and the rollback is recorded.
- **Retirement:** Git history, content, manifests and evaluation evidence are archived to immutable storage, then the Foundry versions are deleted.

## What goes where

| Item | Use it for |
|---|---|
| **Agent instructions** (GA) | The agent's core behaviour and mandatory rules. They are always in context, so a must-follow rule always applies, and the version shows in traces. |
| **Skills** (preview) | Reusable guidance shared by several agents, such as an escalation policy or response style. Loaded when relevant; never the only home of a mandatory rule. |
| **Toolbox** (skill discovery in preview) | The agent's tools and skill references. Skill versions are always pinned so what runs is deterministic. |

## Recommendation

Skills are versioned and reused. Agents use them through a toolbox. Evaluation benchmarks the agent with those skills and tools, and drift detection watches production against the evaluated baseline.

When a shared skill changes, every agent that uses it is re-evaluated before its toolbox pins the new version.

:::caution
Skills and toolbox skill discovery are preview features. Mandatory rules stay in the agent instructions, so agents keep working correctly if those features change.
:::
