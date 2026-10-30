import type { ZudokuConfig } from "zudoku";
import { portalConfig, type Registry } from "./portal/portal";
import section from "./section.json";
import sections from "./sections.json";

// This repo publishes only its own section of the portal (section.json).
// sections.json lists every section; npm run dev/build refresh it from the hub.
const registry: Registry = sections;

const config: ZudokuConfig = {
  ...portalConfig(registry, section.id),
  site: { title: section.label },
  navigation: [
    {
      type: "category",
      label: section.label,
      items: ["/welcome"],
    },
  ],
  redirects: [{ from: "/", to: "/welcome" }],
};

export default config;
