/**
 * Normalize exercises.json anatomy fields to detailed canonical muscle codes.
 *
 * Usage:
 *   node scripts/req30_normalize_exercises_json.js
 */

const fs = require("fs");
const path = require("path");

const EXERCISES_JSON_PATH = process.env.EXERCISES_JSON_PATH
  ? path.resolve(process.env.EXERCISES_JSON_PATH)
  : path.resolve(process.cwd(), "exercises.json");
const TAXONOMY_PATH = process.env.ANATOMY_TAXONOMY_PATH
  ? path.resolve(process.env.ANATOMY_TAXONOMY_PATH)
  : path.resolve(process.cwd(), "config/anatomy_taxonomy.v1.json");
const REVIEW_PATH = process.env.REVIEW_REPORT_PATH
  ? path.resolve(process.env.REVIEW_REPORT_PATH)
  : path.resolve(process.cwd(), "reports/req30_exercises_json_review_required.json");

function toSnake(raw) {
  if (!raw) return null;
  return String(raw)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_+/g, "_");
}

const taxonomy = JSON.parse(fs.readFileSync(TAXONOMY_PATH, "utf8"));
const detailedSet = new Set(taxonomy.detailed_muscle_codes ?? []);
const groupToDetailed = taxonomy.group_to_detailed ?? {};
const legacyAliases = taxonomy.legacy_aliases ?? {};
const aliasToTarget = {};

for (const [target, aliases] of Object.entries(legacyAliases)) {
  aliasToTarget[target] = target;
  for (const alias of aliases) {
    const normalized = toSnake(alias);
    if (normalized) aliasToTarget[normalized] = target;
  }
}
for (const group of Object.keys(groupToDetailed)) {
  aliasToTarget[group] = group;
}

function resolveCodes(raw) {
  const code = toSnake(raw);
  if (!code) return [];
  if (detailedSet.has(code)) return [code];
  if (groupToDetailed[code]) return groupToDetailed[code];
  const target = aliasToTarget[code];
  if (!target) return [];
  if (detailedSet.has(target)) return [target];
  return groupToDetailed[target] ?? [];
}

function normalizeList(input) {
  const list = Array.isArray(input) ? input : [];
  const resolved = [];
  const unresolved = [];
  const seen = new Set();
  for (const raw of list) {
    const codes = resolveCodes(raw);
    if (codes.length === 0) {
      unresolved.push(String(raw));
      continue;
    }
    for (const code of codes) {
      if (!seen.has(code)) {
        seen.add(code);
        resolved.push(code);
      }
    }
  }
  return { resolved, unresolved };
}

function inferFallbackPrimary(exercise) {
  const name = String(exercise.name ?? "").toLowerCase();
  if (name.includes("raise") || name.includes("press") || name.includes("delt")) {
    return ["deltoid_lateral"];
  }
  if (name.includes("row") || name.includes("pull")) {
    return ["latissimus_dorsi"];
  }
  if (name.includes("curl") || name.includes("wrist") || name.includes("finger")) {
    return ["brachioradialis"];
  }
  if (name.includes("squat") || name.includes("lunge") || name.includes("leg")) {
    return ["rectus_femoris"];
  }
  return ["rectus_abdominis"];
}

function main() {
  const rawExercises = JSON.parse(fs.readFileSync(EXERCISES_JSON_PATH, "utf8"));
  if (!Array.isArray(rawExercises)) {
    throw new Error("exercises.json must be an array");
  }

  const reviewRequired = [];
  let changed = 0;

  const normalized = rawExercises.map((exercise, idx) => {
    const primarySource = exercise.primary_muscles ?? exercise.primaryMuscles ?? [];
    const secondarySource = exercise.secondary_muscles ?? exercise.secondaryMuscles ?? [];
    const primary = normalizeList(primarySource);
    let secondary = normalizeList(secondarySource);

    if (primary.resolved.length === 0 && secondary.resolved.length > 0) {
      primary.resolved.push(secondary.resolved[0]);
      secondary.resolved = secondary.resolved.slice(1);
    }
    if (primary.resolved.length === 0) {
      primary.resolved.push(...inferFallbackPrimary(exercise));
    }
    secondary.resolved = secondary.resolved.filter((code) => !primary.resolved.includes(code));

    const next = {
      ...exercise,
      primaryMuscles: primary.resolved,
      secondaryMuscles: secondary.resolved,
    };
    delete next.primary_muscles;
    delete next.secondary_muscles;

    const beforePrimary = JSON.stringify(primarySource);
    const beforeSecondary = JSON.stringify(secondarySource);
    if (
      beforePrimary !== JSON.stringify(next.primaryMuscles) ||
      beforeSecondary !== JSON.stringify(next.secondaryMuscles)
    ) {
      changed += 1;
    }

    const unresolved = [...primary.unresolved, ...secondary.unresolved];
    if (unresolved.length > 0 || next.primaryMuscles.length === 0) {
      reviewRequired.push({
        index: idx,
        id: exercise.id ?? null,
        name: exercise.name ?? null,
        unresolved,
        primaryMuscles: next.primaryMuscles,
        secondaryMuscles: next.secondaryMuscles,
      });
    }
    return next;
  });

  fs.writeFileSync(EXERCISES_JSON_PATH, `${JSON.stringify(normalized, null, 2)}\n`, "utf8");
  fs.mkdirSync(path.dirname(REVIEW_PATH), { recursive: true });
  fs.writeFileSync(
    REVIEW_PATH,
    `${JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        total: rawExercises.length,
        changed,
        reviewRequiredCount: reviewRequired.length,
        reviewRequired,
      },
      null,
      2
    )}\n`,
    "utf8"
  );

  console.log(
    JSON.stringify(
      {
        file: EXERCISES_JSON_PATH,
        total: rawExercises.length,
        changed,
        reviewRequired: reviewRequired.length,
        report: REVIEW_PATH,
      },
      null,
      2
    )
  );
}

main();
