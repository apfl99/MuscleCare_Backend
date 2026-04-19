/**
 * Validate detailed anatomy code parity between backend taxonomy and frontend 3D map.
 */

const fs = require("fs");
const path = require("path");

const TAXONOMY_PATH = process.env.ANATOMY_TAXONOMY_PATH
  ? path.resolve(process.env.ANATOMY_TAXONOMY_PATH)
  : path.resolve(process.cwd(), "config/anatomy_taxonomy.v1.json");
const FRONTEND_VIEWER_PATH = process.env.FRONTEND_VIEWER_PATH
  ? path.resolve(process.env.FRONTEND_VIEWER_PATH)
  : path.resolve(
      process.cwd(),
      "../Muscle_Fatigue_Tracker_App-Frontend/lib/widgets/interactive_muscle_3d_viewer.dart"
    );

function parseMapKeys(source, mapName) {
  const marker = `${mapName} = {`;
  const start = source.indexOf(marker);
  if (start < 0) return [];
  let index = start + marker.length;
  let depth = 1;
  while (index < source.length && depth > 0) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    index += 1;
  }
  const body = source.slice(start + marker.length, index - 1);
  return [...body.matchAll(/\n\s*'([^']+)'\s*:\s*\[/g)].map((m) => m[1]);
}

const taxonomy = JSON.parse(fs.readFileSync(TAXONOMY_PATH, "utf8"));
const backendCodes = new Set(taxonomy.detailed_muscle_codes ?? []);

const frontendSource = fs.readFileSync(FRONTEND_VIEWER_PATH, "utf8");
const frontendCodes = new Set(parseMapKeys(frontendSource, "_muscleMeshNodeMap"));

const backendOnly = [...backendCodes].filter((code) => !frontendCodes.has(code)).sort();
const frontendOnly = [...frontendCodes].filter((code) => !backendCodes.has(code)).sort();

const summary = {
  backendDetailedCount: backendCodes.size,
  frontendDetailedCount: frontendCodes.size,
  backendOnlyCount: backendOnly.length,
  frontendOnlyCount: frontendOnly.length,
};

console.log(JSON.stringify(summary, null, 2));
if (backendOnly.length > 0 || frontendOnly.length > 0) {
  console.log(JSON.stringify({ backendOnly, frontendOnly }, null, 2));
  process.exitCode = 1;
}
