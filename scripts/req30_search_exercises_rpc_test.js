/**
 * REQ-30 search_exercises RPC integration test (Node 14+)
 *
 * Required env:
 * - SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional env:
 * - SUPABASE_URL (default: project URL)
 * - SUPABASE_PUBLISHABLE_KEY (default: provided key)
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

function httpJson({ method, path, headers = {}, body = undefined }) {
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

          let parsedBody;
          try {
            parsedBody = text ? JSON.parse(text) : {};
          } catch {
            parsedBody = text;
          }

          resolve({
            status: res.statusCode ?? 0,
            headers: res.headers,
            body: parsedBody,
            elapsedMs,
          });
        });
      }
    );

    req.on("error", reject);
    if (body !== undefined) {
      req.write(payload);
    }
    req.end();
  });
}

function summarizeRuns(runs) {
  const times = runs.map((r) => r.elapsedMs);
  const counts = runs.map((r) => (Array.isArray(r.body) ? r.body.length : null));
  const validTimes = times.filter((t) => Number.isFinite(t));

  return {
    runs: runs.length,
    statusCodes: Array.from(new Set(runs.map((r) => r.status))),
    resultCounts: counts,
    minMs: Math.min(...validTimes),
    maxMs: Math.max(...validTimes),
    avgMs: Number(
      (
        validTimes.reduce((sum, cur) => sum + cur, 0) / Math.max(validTimes.length, 1)
      ).toFixed(2)
    ),
    sampleTop5:
      Array.isArray(runs[0]?.body) && runs[0].body.length > 0
        ? runs[0].body.slice(0, 5)
        : [],
  };
}

async function main() {
  const report = {
    projectUrl: SUPABASE_URL,
    testedAt: new Date().toISOString(),
    migrationTarget: "20260308100000_req30_muscle_standardization.sql",
    steps: {},
  };

  const email = `req30_search_${Date.now()}@gmail.com`;
  const password = "Req30!Pass12345";
  let userId = null;
  let userAccessToken = null;

  try {
    // 1) Create confirmed test user
    const createUser = await httpJson({
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

    // 2) Sign in to obtain user JWT
    const signIn = await httpJson({
      method: "POST",
      path: "/auth/v1/token?grant_type=password",
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
      },
      body: {
        email,
        password,
      },
    });
    userAccessToken = signIn.body?.access_token ?? null;
    report.steps.signIn = {
      status: signIn.status,
      hasAccessToken: Boolean(userAccessToken),
    };

    // 3) Run search RPC tests
    const rpcHeaders = {
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${userAccessToken}`,
    };

    const keywords = [
      { keyword: "squat", runs: 5 },
      { keyword: "스쿼트", runs: 3 },
      { keyword: "ㅅㅋㅌ", runs: 3 },
      { keyword: "벤치프레스", runs: 3 },
      { keyword: "데드리프트", runs: 3 },
      { keyword: "a", runs: 5 },
      { keyword: "", runs: 1 },
    ];

    const searchResults = {};
    for (const item of keywords) {
      const runs = [];
      for (let i = 0; i < item.runs; i += 1) {
        const result = await httpJson({
          method: "POST",
          path: "/rest/v1/rpc/search_exercises",
          headers: rpcHeaders,
          body: {
            p_keyword: item.keyword,
          },
        });
        runs.push(result);
      }
      searchResults[item.keyword === "" ? "<empty>" : item.keyword] = summarizeRuns(runs);
    }
    report.steps.searchRpc = searchResults;

    // 4) Validate LIMIT 20 behavior explicitly (keyword: "a")
    const broad = report.steps.searchRpc.a;
    const allWithin20 = broad.resultCounts.every((count) => (count ?? 0) <= 20);
    report.steps.limitCheck = {
      keyword: "a",
      allRunsWithin20: allWithin20,
      observedCounts: broad.resultCounts,
    };

    report.steps.koreanCoverageCheck = {
      스쿼트: report.steps.searchRpc["스쿼트"].resultCounts,
      "ㅅㅋㅌ": report.steps.searchRpc["ㅅㅋㅌ"].resultCounts,
      벤치프레스: report.steps.searchRpc["벤치프레스"].resultCounts,
      데드리프트: report.steps.searchRpc["데드리프트"].resultCounts,
      allKoreanQueriesHaveResults:
        report.steps.searchRpc["스쿼트"].resultCounts.every((c) => (c ?? 0) > 0) &&
        report.steps.searchRpc["ㅅㅋㅌ"].resultCounts.every((c) => (c ?? 0) > 0) &&
        report.steps.searchRpc["벤치프레스"].resultCounts.every((c) => (c ?? 0) > 0) &&
        report.steps.searchRpc["데드리프트"].resultCounts.every((c) => (c ?? 0) > 0),
    };

    const sample = report.steps.searchRpc["스쿼트"].sampleTop5[0] ?? {};
    report.steps.responseFieldCheck = {
      requiredFields: [
        "id",
        "name",
        "category",
        "exercise_type",
        "muscle_size",
        "primary_muscles",
        "secondary_muscles",
      ],
      sampleKeys: Object.keys(sample),
      hasAllRequiredFields: [
        "id",
        "name",
        "category",
        "exercise_type",
        "muscle_size",
        "primary_muscles",
        "secondary_muscles",
      ].every((key) => Object.prototype.hasOwnProperty.call(sample, key)),
    };
  } finally {
    if (userId) {
      const cleanup = await httpJson({
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
  console.error("Search RPC test failed:", error);
  process.exitCode = 1;
});
