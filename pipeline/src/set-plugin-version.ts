/**
 * Advances the plugin version across every manifest that carries one.
 *
 * Called by the refresh workflow whenever a rebuilt corpus is about to land:
 * without a version bump the new corpus sits on main and no installed plugin
 * ever picks it up. See lib/plugin-version.ts for why.
 *
 * Usage:
 *   tsx src/set-plugin-version.ts             Next CalVer for today.
 *   tsx src/set-plugin-version.ts 27.1.0      Set an explicit version.
 *   pnpm set:version
 *
 * Prints the new version as `version=<v>` on stdout so a workflow can capture
 * it for the commit message.
 */

import {
  PRIMARY_VERSION_FILE,
  SEMVER_RE,
  VERSION_FILES,
  nextCalVer,
  readVersion,
  writeVersion,
} from "./lib/plugin-version.ts";

function main(): void {
  const args = process.argv.slice(2).filter((a) => a !== "--");
  const explicit = args[0];

  const primary = VERSION_FILES[0]!;
  const current = readVersion(primary.file, primary.path);
  const next = explicit ?? nextCalVer(current);

  if (!SEMVER_RE.test(next)) {
    console.error(
      `Refusing to write "${next}": must be MAJOR.MINOR.PATCH with no leading zeros ` +
        `(semver rejects "26.09.0"; use "26.9.0").`,
    );
    process.exit(1);
  }

  if (current === next) {
    console.log(`Already at ${next} — unchanged.`);
    console.log(`version=${next}`);
    return;
  }

  for (const { file, path } of VERSION_FILES) {
    writeVersion(file, path, next);
    console.log(`${file}: ${path.join(".")} → ${next}`);
  }

  console.log(`${String(current)} → ${next} (from ${PRIMARY_VERSION_FILE})`);
  console.log(`version=${next}`);
}

main();
