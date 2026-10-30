import { existsSync, readdirSync, readFileSync } from "node:fs";
import type { ZudokuConfig } from "zudoku";

// Each team's repo is checked out into pages/<team>/ and ships a nav.json
// that becomes its own top-level tab.
const teamSections = readdirSync("pages", { withFileTypes: true })
  .filter((d) => d.isDirectory() && existsSync(`pages/${d.name}/nav.json`))
  .map((d) => ({
    type: "category" as const,
    ...JSON.parse(readFileSync(`pages/${d.name}/nav.json`, "utf8")),
  }));

const config: ZudokuConfig = {
  site: {
    logo: {
      src: { light: "/logo-light.svg", dark: "/logo-dark.svg" },
      alt: "Zudoku",
      width: "130px",
    },
  },
  navigation: [
    {
      type: "category",
      label: "Architecture",
      items: [
        "/architecture/overview",
        "/architecture/capabilities",
        "/architecture/consumption-patterns",
        "/architecture/landing-zones",
        "/architecture/communication-flows",
        "/architecture/security",
        "/architecture/observability",
        "/architecture/governance",
        "/architecture/promptops",
        "/architecture/agent-monitoring",
        "/architecture/docs-portal",
      ],
    },
    ...teamSections,
    {
      type: "category",
      label: "Documentation",
      items: [
        {
          type: "category",
          label: "Getting Started",
          icon: "sparkles",
          items: [
            "/introduction",
            "/guides/getting-started",
            {
              type: "link",
              icon: "folder-cog",
              badge: {
                label: "New",
                color: "purple",
              },
              label: "API Reference",
              to: "/api",
            },
          ],
        },
        {
          type: "category",
          label: "Useful Links",
          collapsible: false,
          icon: "link",
          items: [
            {
              type: "link",
              icon: "book",
              label: "Zudoku Docs",
              to: "https://zudoku.dev/docs/",
            },
          ],
        },
      ],
    },
    {
      type: "link",
      to: "/api",
      label: "API Reference",
    },
  ],
  redirects: [{ from: "/", to: "/architecture/overview" }],
  apis: [
    {
      type: "file",
      input: "./apis/openapi.yaml",
      path: "/api",
    },
  ],
};

export default config;
