/**
 * REQ-30 Sprint verification:
 * - search_exercises returns primary/secondary muscle arrays
 * - get_muscle_heatmap_status returns weighted fatigue scores
 *
 * Required env:
 * - SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional env:
 * - SUPABASE_URL
 * - SUPABASE_PUBLISHABLE_KEY
 */

const https = require("https");
const { URL } = require("url");
const { performance } = require("perf_hooks");

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? "https://ialgqpzyysctbtqrwyqq.supabase.co";
const SUPABASE_PUBLISHABLE_KEY =
  process.env.SUPABASE_PUBLISHABLE_KEY ??
  "sb_publishable_tBWvZfUGmzEP9BJWcZCKMA_wFIXV6N1";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY is required.");
  process.exit(1);
}

const PLACEHOLDER_TEXTS = new Set([
  "",
  "근육부위",
  "근육 부위",
  "기타 근육",
  "unknown",
  "other",
  "placeholder",
]);

function isPlaceholderText(value) {
  const normalized = String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
  return PLACEHOLDER_TEXTS.has(normalized);
}

function requestJson({ method, path, headers = {}, body }) {
  const url = new URL(path, SUPABASE_URL);
  const payload = body === undefined ? "" : JSON.stringify(body);

  return new Promise((resolve, reject) => {
    const started = performance.now();
    const req = https.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port || 443,
        path: `${url.pathname}${url.search}`,
        method,
        headers: {
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
          const elapsedMs = Number((performance.now() - started).toFixed(2));
          const text = Buffer.concat(chunks).toString("utf8");
          let parsed;
          try {
            parsed = text ? JSON.parse(text) : {};
          } catch {
            parsed = text;
          }
          resolve({
            status: res.statusCode ?? 0,
            elapsedMs,
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

async function main() {
  const report = {
    projectUrl: SUPABASE_URL,
    testedAt: new Date().toISOString(),
    migrationTarget: "20260308100000_req30_muscle_standardization.sql",
    steps: {},
  };

  const email = `req30_anatomy_${Date.now()}@gmail.com`;
  const password = "Req30!Pass12345";
  let userId = null;
  let pickedExercise = null;

  try {
    const createUser = await requestJson({
      method: "POST",
      path: "/auth/v1/admin/users",
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: {
        email,
        password,
        email_confirm: true,
      },
    });
    userId = createUser.body?.id ?? null;
    report.steps.createUser = {
      status: createUser.status,
      userId,
    };

    const signIn = await requestJson({
      method: "POST",
      path: "/auth/v1/token?grant_type=password",
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
      },
      body: { email, password },
    });
    const accessToken = signIn.body?.access_token ?? "";
    report.steps.signIn = {
      status: signIn.status,
      hasAccessToken: Boolean(accessToken),
    };

    const userHeaders = {
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${accessToken}`,
    };
    const serviceHeaders = {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    };

    const search = await requestJson({
      method: "POST",
      path: "/rest/v1/rpc/search_exercises",
      headers: userHeaders,
      body: { p_keyword: "squat" },
    });
    const results = Array.isArray(search.body) ? search.body : [];
    pickedExercise =
      results.find(
        (row) =>
          Array.isArray(row.primary_muscles) &&
          row.primary_muscles.length > 0 &&
          Array.isArray(row.secondary_muscles)
      ) ?? null;

    report.steps.searchExercises = {
      status: search.status,
      elapsedMs: search.elapsedMs,
      resultCount: results.length,
      firstItemKeys: results[0] ? Object.keys(results[0]) : [],
      pickedExercise,
    };

    if (!pickedExercise) {
      throw new Error("No searchable exercise with anatomy arrays found.");
    }

    const insertPayload =
      pickedExercise.exercise_type === "cardio"
        ? {
            user_id: userId,
            exercise_id: pickedExercise.id,
            duration_minutes: 15,
            distance_km: 2.5,
            note: "req30_anatomy_test",
          }
        : {
            user_id: userId,
            exercise_id: pickedExercise.id,
            sets: 3,
            reps: 8,
            weight_kg: 30,
            note: "req30_anatomy_test",
          };

    const insertA = await requestJson({
      method: "POST",
      path: "/rest/v1/workout_logs",
      headers: {
        ...userHeaders,
        Prefer: "return=representation",
      },
      body: [insertPayload],
    });
    const insertB = await requestJson({
      method: "POST",
      path: "/rest/v1/workout_logs",
      headers: {
        ...userHeaders,
        Prefer: "return=representation",
      },
      body: [insertPayload],
    });
    report.steps.insertLogs = {
      first: insertA.status,
      second: insertB.status,
    };

    const heatmap = await requestJson({
      method: "POST",
      path: "/rest/v1/rpc/get_muscle_heatmap_status",
      headers: userHeaders,
      body: { p_user_id: userId },
    });
    const heatmapRows = Array.isArray(heatmap.body) ? heatmap.body : [];

    const invalidContractRows = heatmapRows.filter((row) => {
      const muscleCode = row.muscle_code ?? "";
      const displayNameKo = row.display_name_ko ?? "";
      const hasRequiredFields =
        Object.prototype.hasOwnProperty.call(row, "muscle_code") &&
        Object.prototype.hasOwnProperty.call(row, "display_name_ko");
      const validCode = /^[a-z0-9_]+$/.test(String(muscleCode));
      const validNameKo = !isPlaceholderText(displayNameKo);
      return !hasRequiredFields || !validCode || !validNameKo;
    });

    const primaryTarget = pickedExercise.primary_muscles?.[0] ?? null;
    const secondaryTarget = pickedExercise.secondary_muscles?.[0] ?? null;
    const primaryRow = primaryTarget
      ? heatmapRows.find(
          (row) => row.muscle_code === primaryTarget || row.muscle === primaryTarget
        )
      : null;
    const secondaryRow = secondaryTarget
      ? heatmapRows.find(
          (row) => row.muscle_code === secondaryTarget || row.muscle === secondaryTarget
        )
      : null;

    report.steps.heatmap = {
      status: heatmap.status,
      elapsedMs: heatmap.elapsedMs,
      totalMuscles: heatmapRows.length,
      invalidContractCount: invalidContractRows.length,
      invalidContractSample: invalidContractRows.slice(0, 3),
      primaryTarget,
      primaryRow,
      secondaryTarget,
      secondaryRow,
      weightedScoreCheck:
        primaryRow && secondaryRow
          ? Number(primaryRow.fatigue_score) > Number(secondaryRow.fatigue_score)
          : null,
    };

    const sampleMuscleRows = await requestJson({
      method: "GET",
      path: "/rest/v1/exercises?select=id,name,primary_muscles,secondary_muscles&order=name.asc&limit=5",
      headers: serviceHeaders,
    });
    report.steps.sampleExercises = {
      status: sampleMuscleRows.status,
      rows: sampleMuscleRows.body,
    };

    const muscleMaster = await requestJson({
      method: "GET",
      path: "/rest/v1/muscles?select=code,display_name_ko,display_name_latin,anatomy_id,parent_muscle_code,side&order=display_order.asc&limit=500",
      headers: serviceHeaders,
    });
    const masterRows = Array.isArray(muscleMaster.body) ? muscleMaster.body : [];
    const invalidMasterRows = masterRows.filter((row) => {
      const validCode = /^[a-z0-9_]+$/.test(String(row.code ?? ""));
      const validDisplayNameKo = !isPlaceholderText(row.display_name_ko);
      return !validCode || !validDisplayNameKo;
    });
    report.steps.muscleMasterContract = {
      status: muscleMaster.status,
      total: masterRows.length,
      invalidCount: invalidMasterRows.length,
      invalidSample: invalidMasterRows.slice(0, 3),
    };
  } finally {
    if (userId) {
      await requestJson({
        method: "DELETE",
        path: `/rest/v1/workout_logs?user_id=eq.${userId}&note=like.req30_anatomy_test%25`,
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          Prefer: "return=minimal",
        },
      });

      const cleanup = await requestJson({
        method: "DELETE",
        path: `/auth/v1/admin/users/${userId}`,
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      });
      report.steps.cleanupUser = {
        status: cleanup.status,
      };
    }
  }

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error("REQ30 anatomy RPC test failed:", error);
  process.exitCode = 1;
});
