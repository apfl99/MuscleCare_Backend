/**
 * Validate exercises.json quality against detailed canonical anatomy taxonomy.
 */

const fs = require("fs");
const path = require("path");

const EXERCISES_JSON_PATH = process.env.EXERCISES_JSON_PATH
  ? path.resolve(process.env.EXERCISES_JSON_PATH)
  : path.resolve(process.cwd(), "exercises.json");
const TAXONOMY_PATH = process.env.ANATOMY_TAXONOMY_PATH
  ? path.resolve(process.env.ANATOMY_TAXONOMY_PATH)
  : path.resolve(process.cwd(), "config/anatomy_taxonomy.v1.json");

const taxonomy = JSON.parse(fs.readFileSync(TAXONOMY_PATH, "utf8"));
const detailedSet = new Set(taxonomy.detailed_muscle_codes ?? []);
const exercises = JSON.parse(fs.readFileSync(EXERCISES_JSON_PATH, "utf8"));

const violations = [];

for (const [index, item] of exercises.entries()) {
  const name = item.name ?? item.id ?? `index_${index}`;
  const primary = Array.isArray(item.primaryMuscles)
    ? item.primaryMuscles
    : Array.isArray(item.primary_muscles)
      ? item.primary_muscles
      : [];
  const secondary = Array.isArray(item.secondaryMuscles)
    ? item.secondaryMuscles
    : Array.isArray(item.secondary_muscles)
      ? item.secondary_muscles
      : [];

  if (primary.length === 0) {
    violations.push({ index, name, type: "missing_primary" });
  }

  for (const code of primary) {
    if (!detailedSet.has(code)) {
      violations.push({ index, name, type: "non_canonical_primary", code });
    }
  }
  for (const code of secondary) {
    if (!detailedSet.has(code)) {
      violations.push({ index, name, type: "non_canonical_secondary", code });
    }
  }

  const overlap = secondary.filter((code) => primary.includes(code));
  for (const code of overlap) {
    violations.push({ index, name, type: "primary_secondary_overlap", code });
  }
}

const summary = {
  totalExercises: exercises.length,
  totalViolations: violations.length,
  violationTypes: violations.reduce((acc, v) => {
    acc[v.type] = (acc[v.type] ?? 0) + 1;
    return acc;
  }, {}),
};

console.log(JSON.stringify(summary, null, 2));
if (violations.length > 0) {
  console.log(JSON.stringify({ sampleViolations: violations.slice(0, 20) }, null, 2));
  process.exitCode = 1;
}
