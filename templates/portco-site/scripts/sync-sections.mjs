// Refreshes sections.json (the portal's list of sections) from the hub repo so
// the PortCos menu links to every section. Runs before dev and build; keeps the
// existing copy if the hub can't be reached.
import { readFileSync, writeFileSync } from "node:fs";

const url =
  "https://raw.githubusercontent.com/DeepuMM/zudoku-docs-portal/main/sections.json";
const section = JSON.parse(readFileSync("section.json", "utf8"));

let registry;
try {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  registry = await res.json();
} catch (err) {
  console.warn(`sync-sections: could not fetch ${url} (${err.message}); keeping local copy`);
  registry = JSON.parse(readFileSync("sections.json", "utf8"));
}

// A new PortCo works before the hub lists it.
if (!registry.sections.some((s) => s.id === section.id)) registry.sections.push(section);
writeFileSync("sections.json", JSON.stringify(registry, null, 2) + "\n");
