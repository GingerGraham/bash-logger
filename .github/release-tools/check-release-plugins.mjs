// Check that the release tooling installed in this directory can load everything that
// .releaserc.json names: semantic-release, every plugin, and the changelog preset.
//
// Run it after `npm ci --prefix .github/release-tools`. The release job only installs the
// tools when a release is due, so a broken lockfile or an incompatible Node version would
// otherwise first show up while releasing. This needs no credentials, unlike a dry run.

import { readFileSync } from "node:fs";

const config = JSON.parse(
  readFileSync(new URL("../../.releaserc.json", import.meta.url), "utf8"),
);

const packageNames = new Set(["semantic-release"]);
for (const plugin of config.plugins) {
  const [name, options] = Array.isArray(plugin) ? plugin : [plugin, {}];
  packageNames.add(name);
  // The release notes and commit analyzer plugins load a preset by name
  if (options && options.preset) {
    packageNames.add(`conventional-changelog-${options.preset}`);
  }
}

let failures = 0;
for (const name of [...packageNames].sort()) {
  try {
    // Import resolves from this file, so only this directory's node_modules can satisfy it
    await import(name);
    const manifest = JSON.parse(
      readFileSync(new URL(`./node_modules/${name}/package.json`, import.meta.url), "utf8"),
    );
    console.log(`ok    ${name} ${manifest.version}`);
  } catch (error) {
    failures += 1;
    console.log(`FAIL  ${name}: ${error.message}`);
  }
}

if (failures > 0) {
  console.error(`${failures} package(s) did not load`);
  process.exit(1);
}
console.log(`${packageNames.size} packages loaded on Node ${process.versions.node}`);
