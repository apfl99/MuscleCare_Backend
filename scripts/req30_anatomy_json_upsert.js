/**
 * REQ-30 Sprint: exercises.json anatomy upsert (non-destructive)
 *
 * Required env:
 * - SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional env:
 * - SUPABASE_URL
 * - EXERCISES_JSON_PATH (default: ./exercises.json)
 */

const fs = require("fs");
const path = require("path");
const https = require("https");
const { URL } = require("url");

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? "https://ialgqpzyysctbtqrwyqq.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
const EXERCISES_JSON_PATH = process.env.EXERCISES_JSON_PATH
  ? path.resolve(process.env.EXERCISES_JSON_PATH)
  : path.resolve(process.cwd(), "exercises.json");

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY is required.");
  process.exit(1);
}

function toSnake(raw) {
  if (!raw) return null;
  const value = String(raw).trim().toLowerCase();
  if (!value) return null;
  const normalized = value
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_+/g, "_");
  return normalized || null;
}

const MUSCLE_ALIAS_TO_CANONICAL = {
  chest: "chest",
  upper_chest: "upper_chest",
  serratus_anterior: "serratus_anterior",
  shoulders: "shoulders",
  shoulder: "shoulders",
  deltoids: "shoulders",
  front_deltoid: "front_deltoid",
  lateral_deltoid: "lateral_deltoid",
  rear_deltoid: "rear_deltoid",
  traps: "traps",
  trapezius: "traps",
  upper_trapezius: "upper_trapezius",
  middle_trapezius: "middle_trapezius",
  lower_trapezius: "lower_trapezius",
  lats: "lats",
  middle_back: "middle_back",
  middleback: "middle_back",
  rhomboids: "rhomboids",
  lower_back: "lower_back",
  lowerback: "lower_back",
  spinal_erectors: "spinal_erectors",
  erector_spinae: "spinal_erectors",
  biceps: "biceps",
  triceps: "triceps",
  forearms: "forearms",
  forearm: "forearms",
  forearm_flexors: "forearm_flexors",
  forearm_extensors: "forearm_extensors",
  abdominals: "abdominals",
  core: "abdominals",
  transverse_abdominis: "transverse_abdominis",
  abs: "abs",
  rectus_abdominis: "abs",
  obliques: "obliques",
  hip_flexors: "hip_flexors",
  glutes: "glutes",
  abductors: "abductors",
  adductors: "adductors",
  quadriceps: "quadriceps",
  hamstrings: "hamstrings",
  calves: "calves",
  tibialis_anterior: "tibialis_anterior",
  neck: "neck",
};

function toCanonicalMuscleCode(raw) {
  const snake = toSnake(raw);
  if (!snake) return null;
  return MUSCLE_ALIAS_TO_CANONICAL[snake] ?? null;
}

function normalizeText(raw) {
  if (raw === undefined || raw === null) return null;
  const value = String(raw).trim();
  return value === "" ? null : value;
}

function normalizeMuscles(input) {
  const array = Array.isArray(input) ? input : [];
  const set = new Set();
  for (const item of array) {
    const normalized = toCanonicalMuscleCode(item);
    if (normalized) set.add(normalized);
  }
  return Array.from(set);
}

function inferCategory(sourceCategory, sourceEquipment) {
  const category = String(sourceCategory ?? "")
    .trim()
    .toLowerCase();
  const equipment = String(sourceEquipment ?? "")
    .trim()
    .toLowerCase();

  if (category === "cardio") return "cardio";
  if (category === "plyometrics") return "plyometric";
  if (category.includes("olympic")) return "olympic";
  if (category.includes("strongman")) return "strongman";
  if (equipment.includes("cable")) return "cable";
  if (equipment.includes("band")) return "band";
  if (equipment.includes("kettlebell")) return "kettlebell";
  if (equipment.includes("machine")) return "machine";
  if (equipment.includes("body")) return "bodyweight";
  return "free_weight";
}

function inferExerciseType(category) {
  return category === "cardio" ? "cardio" : "weight";
}

function inferMuscleSize(exerciseType, primaryMuscles) {
  if (exerciseType === "cardio") return "large";
  const largeSet = new Set([
    "chest",
    "upper_chest",
    "lats",
    "middle_back",
    "lower_back",
    "traps",
    "spinal_erectors",
    "quadriceps",
    "hamstrings",
    "glutes",
    "adductors",
    "abductors",
  ]);
  for (const muscle of primaryMuscles) {
    if (largeSet.has(muscle)) return "large";
  }
  return "small";
}

function slugify(raw) {
  const snake = toSnake(raw);
  if (snake) return snake;
  return `exercise_${Buffer.from(String(raw ?? "exercise"))
    .toString("hex")
    .slice(0, 16)}`;
}

function buildBiomechanicsNote(item) {
  const directNote = normalizeText(item.biomechanics_note ?? item.biomechanicsNote);
  if (directNote) return directNote;

  const parts = [
    normalizeText(item.force),
    normalizeText(item.level),
    normalizeText(item.mechanic),
  ].filter(Boolean);
  if (parts.length > 0) {
    return `force=${parts[0] ?? "-"}, level=${parts[1] ?? "-"}, mechanic=${parts[2] ?? "-"}`;
  }
  return null;
}

function requestJson({ method, path, headers = {}, body }) {
  const url = new URL(path, SUPABASE_URL);
  const payload = body === undefined ? "" : JSON.stringify(body);
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port || 443,
        path: `${url.pathname}${url.search}`,
        method,
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          ...headers,
          ...(body === undefined
            ? {}
            : {
                "Content-Type": "application/json",
                "Content-Length": Buffer.byteLength(payload),
              }),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8");
          let parsed;
          try {
            parsed = text ? JSON.parse(text) : {};
          } catch {
            parsed = text;
          }
          resolve({
            status: res.statusCode ?? 0,
            body: parsed,
          });
        });
      }
    );
    req.on("error", reject);
    if (body !== undefined) req.write(payload);
    req.end();
  });
}

async function fetchAllExercises() {
  const limit = 1000;
  let offset = 0;
  const rows = [];

  while (true) {
    const response = await requestJson({
      method: "GET",
      path: `/rest/v1/exercises?select=id,name,slug&order=name.asc&limit=${limit}&offset=${offset}`,
    });
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`Failed to fetch exercises: HTTP ${response.status} ${JSON.stringify(response.body)}`);
    }

    const batch = Array.isArray(response.body) ? response.body : [];
    rows.push(...batch);
    if (batch.length < limit) break;
    offset += limit;
  }

  return rows;
}

async function patchExerciseById(id, payload) {
  const response = await requestJson({
    method: "PATCH",
    path: `/rest/v1/exercises?id=eq.${encodeURIComponent(id)}`,
    headers: {
      Prefer: "return=minimal",
    },
    body: payload,
  });

  if (response.status < 200 || response.status >= 300) {
    throw new Error(
      `Failed to update exercise(${id}): HTTP ${response.status} ${JSON.stringify(response.body)}`
    );
  }
}

async function insertExercisesBatch(rows) {
  if (rows.length === 0) return;
  const response = await requestJson({
    method: "POST",
    path: "/rest/v1/exercises",
    headers: {
      Prefer: "return=minimal",
    },
    body: rows,
  });
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`Failed to insert exercises: HTTP ${response.status} ${JSON.stringify(response.body)}`);
  }
}

async function main() {
  const raw = JSON.parse(fs.readFileSync(EXERCISES_JSON_PATH, "utf8"));
  if (!Array.isArray(raw)) {
    throw new Error("exercises.json must be an array");
  }

  const existingRows = await fetchAllExercises();
  const existingByName = new Map();
  const usedSlugs = new Set();

  for (const row of existingRows) {
    existingByName.set(String(row.name).trim().toLowerCase(), row);
    usedSlugs.add(String(row.slug));
  }

  const updates = [];
  const inserts = [];
  let skipped = 0;

  for (const item of raw) {
    const nameKo = normalizeText(
      item.exercise_name_ko ?? item.name_ko ?? item.nameKo ?? item.korean_name
    );
    const nameEn = normalizeText(
      item.exercise_name_en ?? item.name_en ?? item.nameEn ?? item.name
    );
    const candidateNames = [nameKo, nameEn].filter(Boolean);

    if (candidateNames.length === 0) {
      skipped += 1;
      continue;
    }

    let matched = null;
    for (const candidate of candidateNames) {
      const key = candidate.toLowerCase();
      if (existingByName.has(key)) {
        matched = existingByName.get(key);
        break;
      }
    }

    const primaryMuscles = normalizeMuscles(
      item.primary_muscles ?? item.primaryMuscles ?? []
    );
    const secondaryMuscles = normalizeMuscles(
      item.secondary_muscles ?? item.secondaryMuscles ?? []
    );
    const biomechanicsNote = buildBiomechanicsNote(item);

    if (matched) {
      updates.push({
        id: matched.id,
        primary_muscles: primaryMuscles,
        secondary_muscles: secondaryMuscles,
        biomechanics_note: biomechanicsNote,
      });
      continue;
    }

    const nameForInsert = nameEn ?? nameKo;
    let slug = slugify(nameForInsert);
    if (!slug) {
      skipped += 1;
      continue;
    }
    if (usedSlugs.has(slug)) {
      let seq = 1;
      while (usedSlugs.has(`${slug}_${seq}`)) {
        seq += 1;
      }
      slug = `${slug}_${seq}`;
    }
    usedSlugs.add(slug);

    const inferredCategory = inferCategory(item.category, item.equipment);
    const exerciseType = inferExerciseType(inferredCategory);
    const muscleSize = inferMuscleSize(exerciseType, primaryMuscles);
    const equipment = normalizeText(item.equipment) ?? "unknown";

    inserts.push({
      slug,
      name: nameForInsert,
      category: inferredCategory,
      equipment,
      exercise_type: exerciseType,
      muscle_size: muscleSize,
      primary_muscles: primaryMuscles,
      secondary_muscles: secondaryMuscles,
      biomechanics_note: biomechanicsNote,
    });
  }

  for (const row of updates) {
    await patchExerciseById(row.id, {
      primary_muscles: row.primary_muscles,
      secondary_muscles: row.secondary_muscles,
      biomechanics_note: row.biomechanics_note,
    });
  }

  const batchSize = 200;
  for (let i = 0; i < inserts.length; i += batchSize) {
    const chunk = inserts.slice(i, i + batchSize);
    await insertExercisesBatch(chunk);
  }

  const summary = {
    sourceFile: EXERCISES_JSON_PATH,
    sourceTotal: raw.length,
    existingBefore: existingRows.length,
    updatedExisting: updates.length,
    insertedNew: inserts.length,
    skipped,
    finishedAt: new Date().toISOString(),
  };

  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error("REQ30 anatomy upsert failed:", error);
  process.exitCode = 1;
});
