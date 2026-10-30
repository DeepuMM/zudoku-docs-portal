import type { ZudokuConfig } from "zudoku";
import { portalConfig, type Registry } from "./portal/portal";
import sections from "./sections.json";

// The hub owns sections.json (the list of PortCo sections) and publishes the
// site root. Each PortCo publishes its own section from its own repo.
const registry: Registry = sections;

const config: ZudokuConfig = {
  ...portalConfig(registry, "datax"),
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
    {
      type: "category",
      label: "PortCos",
      items: ["/portcos"],
    },
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
