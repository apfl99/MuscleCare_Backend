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
const ANATOMY_TAXONOMY_PATH = process.env.ANATOMY_TAXONOMY_PATH
  ? path.resolve(process.env.ANATOMY_TAXONOMY_PATH)
  : path.resolve(process.cwd(), "config/anatomy_taxonomy.v1.json");
const REVIEW_REPORT_PATH = process.env.REVIEW_REPORT_PATH
  ? path.resolve(process.env.REVIEW_REPORT_PATH)
  : path.resolve(process.cwd(), "reports/req30_exercise_review_required.json");

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

const taxonomy = JSON.parse(fs.readFileSync(ANATOMY_TAXONOMY_PATH, "utf8"));
const DETAILED_MUSCLE_SET = new Set(taxonomy.detailed_muscle_codes ?? []);
const GROUP_TO_DETAILED = taxonomy.group_to_detailed ?? {};
const legacyAliases = taxonomy.legacy_aliases ?? {};

const ALIAS_TO_TARGET = {};
for (const [targetCode, aliases] of Object.entries(legacyAliases)) {
  ALIAS_TO_TARGET[targetCode] = targetCode;
  for (const alias of aliases) {
    const normalizedAlias = toSnake(alias);
    if (normalizedAlias) {
      ALIAS_TO_TARGET[normalizedAlias] = targetCode;
    }
  }
}
for (const group of Object.keys(GROUP_TO_DETAILED)) {
  ALIAS_TO_TARGET[group] = group;
}

function resolveMuscleCodes(raw) {
  const snake = toSnake(raw);
  if (!snake) return [];
  if (DETAILED_MUSCLE_SET.has(snake)) return [snake];
  if (GROUP_TO_DETAILED[snake]) return GROUP_TO_DETAILED[snake];

  const target = ALIAS_TO_TARGET[snake];
  if (!target) return [];
  if (DETAILED_MUSCLE_SET.has(target)) return [target];
  if (GROUP_TO_DETAILED[target]) return GROUP_TO_DETAILED[target];
  return [];
}

function normalizeText(raw) {
  if (raw === undefined || raw === null) return null;
  const value = String(raw).trim();
  return value === "" ? null : value;
}

function normalizeMuscles(input) {
  const array = Array.isArray(input) ? input : [];
  const set = new Set();
  const unresolved = [];
  for (const item of array) {
    const resolved = resolveMuscleCodes(item);
    if (resolved.length === 0) {
      unresolved.push(String(item));
      continue;
    }
    for (const code of resolved) {
      set.add(code);
    }
  }
  return {
    codes: Array.from(set),
    unresolved,
  };
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
    "pectoralis_major_sternocostal",
    "latissimus_dorsi",
    "trapezius_descending",
    "trapezius_transverse",
    "trapezius_ascending",
    "quadriceps",
    "hamstrings",
    "gluteus_maximus",
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

function inferFallbackPrimary(category) {
  if (category === "cardio") {
    return ["quadriceps"];
  }
  if (category === "machine" || category === "free_weight") {
    return ["pectoralis_major_sternocostal"];
  }
  if (category === "cable") {
    return ["latissimus_dorsi"];
  }
  if (category === "bodyweight") {
    return ["rectus_abdominis"];
  }
  return ["rectus_abdominis"];
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
  const reviewRequired = [];
  const quality = {
    unresolvedTokens: 0,
    duplicateResolved: 0,
    autoPromotedFromSecondary: 0,
    fallbackPrimaryAssigned: 0,
    invalidBiomechanics: 0,
  };
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

    const primaryResult = normalizeMuscles(
      item.primary_muscles ?? item.primaryMuscles ?? []
    );
    const secondaryResult = normalizeMuscles(
      item.secondary_muscles ?? item.secondaryMuscles ?? []
    );
    let primaryMuscles = primaryResult.codes;
    let secondaryMuscles = secondaryResult.codes;

    const unresolved = [...primaryResult.unresolved, ...secondaryResult.unresolved];
    quality.unresolvedTokens += unresolved.length;
    const overlap = secondaryMuscles.filter((code) => primaryMuscles.includes(code));
    if (overlap.length > 0) {
      quality.duplicateResolved += overlap.length;
      secondaryMuscles = secondaryMuscles.filter((code) => !primaryMuscles.includes(code));
    }

    if (primaryMuscles.length === 0 && secondaryMuscles.length > 0) {
      primaryMuscles = [secondaryMuscles[0]];
      secondaryMuscles = secondaryMuscles.slice(1);
      quality.autoPromotedFromSecondary += 1;
    }

    const inferredCategory = inferCategory(item.category, item.equipment);
    if (primaryMuscles.length === 0) {
      primaryMuscles = inferFallbackPrimary(inferredCategory).filter((code) =>
        DETAILED_MUSCLE_SET.has(code)
      );
      quality.fallbackPrimaryAssigned += 1;
    }

    if (primaryMuscles.length === 0) {
      quality.invalidBiomechanics += 1;
      reviewRequired.push({
        name: nameEn ?? nameKo ?? "unknown",
        reason: "primary_empty_after_fallback",
        unresolved,
        sourcePrimary: item.primary_muscles ?? item.primaryMuscles ?? [],
        sourceSecondary: item.secondary_muscles ?? item.secondaryMuscles ?? [],
      });
      skipped += 1;
      continue;
    }

    if (unresolved.length > 0) {
      reviewRequired.push({
        name: nameEn ?? nameKo ?? "unknown",
        reason: "unresolved_tokens",
        unresolved,
        primary_muscles: primaryMuscles,
        secondary_muscles: secondaryMuscles,
      });
    }

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
    reviewRequired: reviewRequired.length,
    quality,
    finishedAt: new Date().toISOString(),
  };

  fs.mkdirSync(path.dirname(REVIEW_REPORT_PATH), { recursive: true });
  fs.writeFileSync(
    REVIEW_REPORT_PATH,
    JSON.stringify(
      {
        sourceFile: EXERCISES_JSON_PATH,
        generatedAt: new Date().toISOString(),
        reviewRequired,
      },
      null,
      2
    ),
    "utf8"
  );

  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error("REQ30 anatomy upsert failed:", error);
  process.exitCode = 1;
});
