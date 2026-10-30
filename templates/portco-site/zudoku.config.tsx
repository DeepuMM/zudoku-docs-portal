import type { ZudokuConfig } from "zudoku";
import { loadRegistry, portalConfig, type Section } from "./portal/portal";

// This repo publishes only its own section of the portal: <portalUrl>/__ID__/
const SECTION: Section = { id: "__ID__", label: "__LABEL__", path: "/__ID__/" };

// Other sections come from the hub's sections.json, fetched at build time.
const registry = await loadRegistry({
  portalUrl: "__PORTAL_URL__",
  sections: [SECTION],
});
if (!registry.sections.some((s) => s.id === SECTION.id)) {
  registry.sections.push(SECTION);
}

const config: ZudokuConfig = {
  ...portalConfig(registry, SECTION.id),
  site: { title: "__LABEL__" },
  navigation: [
    {
      type: "category",
      label: "__LABEL__",
      items: ["/welcome"],
    },
  ],
  redirects: [{ from: "/", to: "/welcome" }],
};

export default config;
