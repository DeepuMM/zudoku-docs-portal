// Shared by the hub and every PortCo site (copied into each PortCo repo by
// scripts/new-portco.ps1). Each section is a separate Zudoku build published to
// its own folder of the storage static website; this file wires them together.
import type { ZudokuConfig, ZudokuPlugin } from "zudoku";

export type Section = {
  id: string;
  label: string;
  path: string; // "/" for the hub, "/<id>/" for a PortCo
  description?: string;
  repo?: string;
};

export type Registry = { portalUrl: string; sections: Section[] };

// The registry lives in the hub repo; PortCo builds fetch the latest copy.
export const REGISTRY_URL =
  "https://raw.githubusercontent.com/DeepuMM/zudoku-docs-portal/main/sections.json";

export const loadRegistry = async (fallback: Registry): Promise<Registry> => {
  try {
    const res = await fetch(REGISTRY_URL);
    if (res.ok) return (await res.json()) as Registry;
  } catch {
    // offline: fall back to the local copy
  }
  return fallback;
};

const portalBase = (registry: Registry) =>
  (process.env.PORTAL_URL ?? registry.portalUrl).replace(/\/+$/, "");

// Which section owns a pathname: the longest matching section path.
const ownerOf = (sections: Section[], pathname: string) =>
  [...sections]
    .sort((a, b) => b.path.length - a.path.length)
    .find((s) => pathname === s.path.replace(/\/$/, "") || pathname.startsWith(s.path))?.id;

// Links into another section must be a full page load: each section is its own
// app, so the current app's client-side router has no routes for it.
const crossSectionLinks = (sections: Section[], currentId: string): ZudokuPlugin => ({
  initialize: () => {
    if (typeof document === "undefined") return;
    document.addEventListener(
      "click",
      (e) => {
        if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey) return;
        const a = (e.target as Element | null)?.closest?.("a[href]") as HTMLAnchorElement | null;
        if (!a || (a.target && a.target !== "_self")) return;
        const url = new URL(a.href, location.href);
        if (url.origin !== location.origin) return;
        if (ownerOf(sections, url.pathname) === currentId) return;
        e.preventDefault();
        e.stopImmediatePropagation();
        location.assign(url.href);
      },
      true,
    );
  },
});

// Config every section shares: base path, the PortCos header menu and the
// cross-section link handling. Each site spreads this into its own config.
export const portalConfig = (registry: Registry, currentId: string) => {
  const current = registry.sections.find((s) => s.id === currentId);
  if (!current) throw new Error(`Section "${currentId}" is not in sections.json`);
  const base = portalBase(registry);

  return {
    basePath: current.path === "/" ? undefined : current.path.replace(/\/$/, ""),
    header: {
      navigation: [
        {
          label: "PortCos",
          items: registry.sections.map((s) => ({
            label: s.label,
            description: s.description,
            to: `${base}${s.path}`,
            target: "_self" as const,
          })),
        },
      ],
    },
    plugins: [crossSectionLinks(registry.sections, currentId)],
  } satisfies Partial<ZudokuConfig>;
};
