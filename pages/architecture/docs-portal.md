---
title: Documentation portal
description: Solution design for a decentralized documentation portal on Zudoku, where Platform and each PortCo publish their own section.
---

**Status:** draft v0.1 · 2026-10-28

## Summary

Platform and every PortCo publish documentation to one site, `docs.<domain>`, built with [Zudoku](https://zudoku.dev). Each owner keeps its content in its own repo and publishes its own section, such as `/platform`, `/portco1` or `/portco2`, on its own schedule. No central build is involved.

A shared preset package from Platform gives every section the same logo, theme and top bar, so readers see one site. The site is hosted as a static website in a Platform storage account, reachable only from the internal network.

![Decentralized documentation portal](/images/architecture/docs-portal.png)

The editable source is `diagrams/docs-portal-architecture.drawio`.

## Requirements

| # | Requirement | How it is met |
|---|---|---|
| R1 | Each PortCo writes and publishes its own content | Each PortCo has its own repo, pipeline and folder in the site |
| R2 | Content lives in the owner's repo | Pages, images and the sidebar are in the PortCo repo; nothing is copied into a Platform repo |
| R3 | One site with one look | The shared `@platform/docs-preset` package and a Platform landing page at `/` |
| R4 | Publishing to a storage account | Static website (`$web`) on a Platform storage account |
| R5 | Internal access only | Private endpoint, no public network access, Application Gateway in front |
| R6 | No stored secrets | GitHub OIDC with Entra federated credentials |
| R7 | One PortCo cannot change another's section | Write access limited to the owner's folder with an ABAC condition |

## Components

### 1. Section repos (one per owner)

Each owner (Platform, PortCo 1, PortCo 2 and so on) has a repo containing a complete Zudoku project:

```
portco1-docs/
├── pages/                 # Markdown / MDX pages
│   ├── index.md
│   └── guides/onboarding.md
├── pages/**/images/       # images next to the pages that use them
├── apis/                  # optional OpenAPI files
├── zudoku.config.tsx      # basePath "/portco1", own sidebar, uses the preset
├── package.json           # pins @platform/docs-preset
└── .github/workflows/docs.yml
```

- `basePath` is the owner's folder, such as `/portco1`. This was tested: every page, script, image and download link is generated with the `/portco1/` prefix.
- Images can sit next to the pages that use them (`![x](./images/x.png)`). The build packages them, which was also tested.
- The owner controls its sidebar, pages and API reference. It does not control the logo, theme or top bar.

### 2. Shared preset package (`@platform/docs-preset`)

Platform publishes a small npm package to the existing Azure Artifacts feed. It contains:

- the logo and theme
- the top bar, linking every section and the landing page
- the footer, such as an owner contact and a "report an issue" link
- shared defaults, such as search and status pages

Each section wraps its own configuration with the preset:

```ts
// zudoku.config.tsx in portco1-docs
import { withPlatformPreset } from "@platform/docs-preset";

export default withPlatformPreset({
  basePath: "/portco1",
  navigation: [
    { type: "category", label: "PortCo 1", items: ["/index", "/guides/onboarding"] },
  ],
});
```

:::caution
Links in the top bar to **other** sections must be full URLs, such as `https://docs.<domain>/portco2/`. A path like `/portco2` would be treated as a page inside the current section and prefixed with its own base path.
:::

### 3. Publishing pipeline (per repo)

| Event | Steps |
|---|---|
| Pull request | `npm ci` → `npm run build` → link check. A failure blocks the merge. |
| Merge to `main` | Build → sign in with OIDC → sync `dist/<section>/` to `$web/<section>/` |

```yaml
# .github/workflows/docs.yml (outline)
on:
  pull_request:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  publish:
    runs-on: [self-hosted, docs]          # must reach the storage private endpoint
    environment: production              # approval rules and the OIDC subject
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
      - run: ./scripts/add-extensionless-copies.sh dist/portco1   # see "Direct links"
      - if: github.ref == 'refs/heads/main'
        uses: azure/login@v2
        with:
          client-id: ${{ vars.DOCS_CLIENT_ID }}
          tenant-id: ${{ vars.PLATFORM_TENANT_ID }}
          allow-no-subscriptions: true
      - if: github.ref == 'refs/heads/main'
        run: |
          azcopy login --login-type=AZCLI
          azcopy sync "dist/portco1" "https://<account>.blob.core.windows.net/\$web/portco1" \
            --delete-destination=true --exclude-pattern="*.map"
```

`--delete-destination=true` removes pages that were deleted from the repo. The ABAC condition below keeps the sync inside the owner's folder.

### 4. Identity

- In the **Platform** tenant, create one app registration (or user-assigned managed identity) per publishing repo.
- Add a **federated credential** that trusts that repo's GitHub OIDC token. Use the environment as the subject, such as `repo:<org>/portco1-docs:environment:production`, so only approved runs on `main` can publish.
- The PortCo does not need a guest account or any secret in the Platform tenant. If your GitHub Enterprise uses a custom OIDC issuer, the federated credential must use that issuer.

### 5. Storage account

Create it with the existing `storage_account` module (v1.0.0.1). Its defaults already turn public network access, shared keys and public blob access off.

| Setting | Value |
|---|---|
| `static_website` | `index_document = "index.html"`, `error_404_document = "404.html"` |
| Public network access | Off (module default) |
| Shared key | Off (module default); all uploads use Entra ID |
| Private endpoint | Sub-resource **`web`**, DNS zone `privatelink.web.core.windows.net` |
| Data protection | Blob versioning and soft delete, for rollback |
| Monitoring | Diagnostic settings to Log Analytics; Defender for Storage |

**Write access per folder.** Each publishing identity gets **Storage Blob Data Contributor** on the account, with a condition that limits writes and deletes to its own folder:

```text
(
  (
    !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'})
    AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action'})
    AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete'})
  )
  OR
  (
    @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals '$web'
    AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path] StringStartsWith 'portco1/'
  )
)
```

### 6. Access path

1. Readers on the corporate network open `https://docs.<domain>/`.
2. Traffic goes through the vWAN secured hub (Azure Firewall, DNS Private Resolver).
3. **Application Gateway with WAF** (existing `app_gateway` module) terminates TLS with the internal certificate for `docs.<domain>`. It forwards to the storage account's `web` private endpoint and rewrites the host header to the static website host name (`<account>.<zone>.web.core.windows.net`).
4. The private endpoint serves the static files.

### 7. Landing page

Platform owns the root of the site (`/`): a short page that explains the portal and links to each section. It is published by the `platform-docs` pipeline, the only identity allowed to write outside a section folder.

## Direct links and refresh

Inside a section, navigation happens in the browser. But when a reader opens `/portco1/guides/onboarding` directly or refreshes, the storage account looks for a blob with exactly that name. The build produces `portco1/guides/onboarding.html`, so the request would return a 404.

**Fix:** after the build, a pipeline step copies every page to a blob without the `.html` extension, with content type `text/html`. Both `/portco1/guides/onboarding` and `/portco1/guides/onboarding.html` then work.

## Onboarding a new PortCo

1. **Platform:** creates the identity, federated credential and ABAC-scoped role assignment for the new folder.
2. **Platform:** allows the PortCo's runner range to reach the storage private endpoint (firewall rule and DNS resolution through the hub).
3. **Platform:** releases a new preset version with the new section in the top bar, and adds it to the landing page.
4. **PortCo:** creates its repo from the starter template, sets `basePath`, and adds the client ID and tenant ID as repo variables.
5. **PortCo:** merges its first content; the pipeline publishes `/<portco>/`.
6. **Other sections:** pick up the new top-bar link when they upgrade the preset.

## Sandbox implementation

A working version runs in the sandbox subscription, on the public static website endpoint (no private endpoint or Application Gateway yet). It simplifies two parts of the design:

- **Section registry instead of a preset release.** The hub repo's `sections.json` lists every section. The hub reads it directly; PortCo builds fetch the latest copy from the hub repo at build time. Adding a PortCo is one change to `sections.json`, and other sections show it after their next build.
- **Shared code is copied, not packaged.** `portal/portal.ts` (base path, PortCos header menu, full page load for cross-section links) is copied into each PortCo repo by the scaffold script. It moves to `@platform/docs-preset` once it settles.

| Piece | Where |
|---|---|
| Hub site, `sections.json`, `/` | `DeepuMM/zudoku-docs-portal`, pipeline `.github/workflows/deploy.yml` |
| PortCo starter | `templates/portco-site/` in the hub repo |
| Scaffold a PortCo repo | `scripts/new-portco.ps1 -Id <id> -Label <name>` |
| Deploy identity, folder-scoped write, repo variables | `scripts/onboard-portco.ps1 -Id <id> -Repo <owner/repo>` |
| Hub deploy identity | `scripts/setup-github-oidc.ps1` |

## Governance

| Area | Rule |
|---|---|
| Ownership | Each PortCo's CODEOWNERS approve its content. Platform owns the preset, landing page and hosting. |
| Consistency | Every section pins a preset version and adopts new releases within the agreed deadline. |
| Quality | A pull request must build and pass the link check before merge. |
| Rollback | Re-run the pipeline on the previous tag, or restore earlier blob versions. |
| Audit | Storage diagnostic logs show which identity wrote or deleted which files. |

## Limitations

- **No search across sections.** Each section searches only its own pages.
- **Moving between sections is a full page load,** because each section is a separate Zudoku site.
- **Everyone who can reach the site can read every section.** Folders control who can *write*, not who can *read*. Content for a restricted audience needs separate hosting with Entra sign-in, such as Azure Static Web Apps or App Service authentication.
- **Preset drift.** Sections on an old preset version show an out-of-date top bar until they upgrade.

## Alternatives considered

| Option | Why not chosen |
|---|---|
| **Central build:** Platform pulls every repo and builds one site | One search and instant navigation, but PortCos cannot publish on their own, and one broken section blocks every release |
| **Separate storage account per PortCo** in its own tenant, routed by Application Gateway | Keeps content in the PortCo tenant (Pattern 3), but needs cross-tenant private endpoints and more infrastructure for no real gain with internal docs |
| **Azure Static Web Apps** | Adds Entra sign-in, but one app serves one build, so the sections still need a router; worth revisiting if per-audience access is needed |

## To be validated in the sandbox

These parts of the design have not been tested yet:

- [ ] The ABAC condition limits `azcopy sync` (including deletes) to the owner's folder.
- [ ] Extensionless copies work for direct links and refresh on the static website endpoint.
- [ ] Application Gateway → `web` private endpoint with the host header rewrite.
- [ ] A PortCo runner reaches the Platform private endpoint through the hub (firewall and DNS).
- [ ] The federated credential works with your GitHub Enterprise OIDC issuer.

## Open decisions

1. The domain name for `docs.<domain>` and its certificate.
2. Whether any section needs a restricted audience. If so, that section needs separate hosting.
3. The preset upgrade deadline, such as 30 days.
4. Whether sections publish from `main` or from release tags.
