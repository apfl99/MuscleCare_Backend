/**
 * REQ-30 V2 integration test:
 * - exercises.exercise_type / muscle_size availability
 * - search_exercises payload enhancement
 * - workout_logs cardio/weight validation behavior
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
            headers: res.headers,
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
    migrationTarget: "20260301070000_req30_v2_cardio_weight_split.sql",
    steps: {},
  };

  const email = `req30_v2_${Date.now()}@gmail.com`;
  const password = "Req30!Pass12345";
  let userId = null;

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
    report.steps.createUser = { status: createUser.status, userId };

    const signIn = await requestJson({
      method: "POST",
      path: "/auth/v1/token?grant_type=password",
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
      },
      body: { email, password },
    });
    const userAccessToken = signIn.body?.access_token ?? null;
    report.steps.signIn = {
      status: signIn.status,
      hasAccessToken: Boolean(userAccessToken),
    };

    const userHeaders = {
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${userAccessToken}`,
    };

    const serviceHeaders = {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    };

    // 1) search_exercises payload check (Korean keyword)
    const searchSquat = await requestJson({
      method: "POST",
      path: "/rest/v1/rpc/search_exercises",
      headers: userHeaders,
      body: { p_keyword: "스쿼트" },
    });
    const firstSquat = Array.isArray(searchSquat.body) ? searchSquat.body[0] : null;
    report.steps.searchExercisesSquat = {
      status: searchSquat.status,
      elapsedMs: searchSquat.elapsedMs,
      resultCount: Array.isArray(searchSquat.body) ? searchSquat.body.length : null,
      firstItemKeys: firstSquat ? Object.keys(firstSquat) : [],
      firstItemPreview: firstSquat,
    };

    // 2) search_exercises payload check (cardio keyword)
    const searchBike = await requestJson({
      method: "POST",
      path: "/rest/v1/rpc/search_exercises",
      headers: userHeaders,
      body: { p_keyword: "bike" },
    });
    report.steps.searchExercisesBike = {
      status: searchBike.status,
      elapsedMs: searchBike.elapsedMs,
      resultCount: Array.isArray(searchBike.body) ? searchBike.body.length : null,
      firstItemPreview: Array.isArray(searchBike.body) ? searchBike.body[0] ?? null : null,
    };

    // 3) pick 1 cardio and 1 weight exercise id
    const cardioExercise = await requestJson({
      method: "GET",
      path: "/rest/v1/exercises?select=id,name,exercise_type,muscle_size&exercise_type=eq.cardio&order=name.asc&limit=1",
      headers: serviceHeaders,
    });
    const weightExercise = await requestJson({
      method: "GET",
      path: "/rest/v1/exercises?select=id,name,exercise_type,muscle_size&exercise_type=eq.weight&order=name.asc&limit=1",
      headers: serviceHeaders,
    });
    const cardio = Array.isArray(cardioExercise.body) ? cardioExercise.body[0] : null;
    const weight = Array.isArray(weightExercise.body) ? weightExercise.body[0] : null;
    report.steps.exerciseTypeSampling = {
      cardio,
      weight,
    };

    // 4) cardio insert success (sets/reps/weight null)
    const cardioInsert = await requestJson({
      method: "POST",
      path: "/rest/v1/workout_logs",
      headers: {
        ...userHeaders,
        Prefer: "return=representation",
      },
      body: [
        {
          user_id: userId,
          exercise_id: cardio?.id,
          duration_minutes: 32,
          distance_km: 5.1,
          sets: null,
          reps: null,
          weight_kg: null,
          note: "req30_v2_test",
        },
      ],
    });
    report.steps.cardioInsertSuccess = {
      status: cardioInsert.status,
      insertedCount: Array.isArray(cardioInsert.body) ? cardioInsert.body.length : null,
      body: cardioInsert.body,
    };

    // 5) weight insert success (sets/reps required)
    const weightInsert = await requestJson({
      method: "POST",
      path: "/rest/v1/workout_logs",
      headers: {
        ...userHeaders,
        Prefer: "return=representation",
      },
      body: [
        {
          user_id: userId,
          exercise_id: weight?.id,
          sets: 4,
          reps: 10,
          weight_kg: 40,
          duration_minutes: null,
          distance_km: null,
          note: "req30_v2_test",
        },
      ],
    });
    report.steps.weightInsertSuccess = {
      status: weightInsert.status,
      insertedCount: Array.isArray(weightInsert.body) ? weightInsert.body.length : null,
      body: weightInsert.body,
    };

    // 6) cardio insert fail when duration missing
    const cardioFail = await requestJson({
      method: "POST",
      path: "/rest/v1/workout_logs",
      headers: {
        ...userHeaders,
        Prefer: "return=representation",
      },
      body: [
        {
          user_id: userId,
          exercise_id: cardio?.id,
          duration_minutes: null,
          sets: null,
          reps: null,
          weight_kg: null,
          note: "req30_v2_test_fail",
        },
      ],
    });
    report.steps.cardioInsertFailWithoutDuration = {
      status: cardioFail.status,
      body: cardioFail.body,
    };

    // 7) weight insert fail when sets/reps missing
    const weightFail = await requestJson({
      method: "POST",
      path: "/rest/v1/workout_logs",
      headers: {
        ...userHeaders,
        Prefer: "return=representation",
      },
      body: [
        {
          user_id: userId,
          exercise_id: weight?.id,
          sets: null,
          reps: 10,
          duration_minutes: null,
          note: "req30_v2_test_fail",
        },
      ],
    });
    report.steps.weightInsertFailWithoutSets = {
      status: weightFail.status,
      body: weightFail.body,
    };

    // 8) schema count check for new columns populated
    const sampleRows = await requestJson({
      method: "GET",
      path: "/rest/v1/exercises?select=id,name,exercise_type,muscle_size&order=name.asc&limit=5",
      headers: serviceHeaders,
    });
    report.steps.exercisesSampleWithNewColumns = {
      status: sampleRows.status,
      rows: sampleRows.body,
    };
  } finally {
    if (userId) {
      await requestJson({
        method: "DELETE",
        path: `/rest/v1/workout_logs?user_id=eq.${userId}&note=like.req30_v2_test%25`,
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          Prefer: "return=representation",
        },
      });

      const cleanupUser = await requestJson({
        method: "DELETE",
        path: `/auth/v1/admin/users/${userId}`,
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      });
      report.steps.cleanupUser = { status: cleanupUser.status };
    }
  }

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error("REQ30 V2 test failed:", error);
  process.exitCode = 1;
});
