/**
 * REQ-30 heatmap RPC test runner (Node 14+)
 *
 * Usage:
 *   SUPABASE_URL=... \
 *   SUPABASE_PUBLISHABLE_KEY=... \
 *   USER_ACCESS_TOKEN=... \
 *   USER_ID=... \
 *   node scripts/req30_heatmap_rpc_test.js
 */

const https = require("https");
const { URL } = require("url");

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? "https://ialgqpzyysctbtqrwyqq.supabase.co";
const SUPABASE_PUBLISHABLE_KEY =
  process.env.SUPABASE_PUBLISHABLE_KEY ??
  "sb_publishable_tBWvZfUGmzEP9BJWcZCKMA_wFIXV6N1";
const USER_ACCESS_TOKEN = process.env.USER_ACCESS_TOKEN ?? "";
const USER_ID = process.env.USER_ID ?? "";

async function callHeatmapRpc({ token, userId }) {
  const rpcUrl = `${SUPABASE_URL}/rest/v1/rpc/get_muscle_heatmap_status`;
  const requestBody = JSON.stringify({ p_user_id: userId });

  const response = await new Promise((resolve, reject) => {
    const url = new URL(rpcUrl);
    const req = https.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port || 443,
        path: `${url.pathname}${url.search}`,
        method: "POST",
        headers: {
          apikey: SUPABASE_PUBLISHABLE_KEY,
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(requestBody),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          resolve({
            status: res.statusCode ?? 0,
            bodyText: Buffer.concat(chunks).toString("utf8"),
          });
        });
      }
    );

    req.on("error", reject);
    req.write(requestBody);
    req.end();
  });

  const bodyText = response.bodyText;
  let body;
  try {
    body = JSON.parse(bodyText);
  } catch {
    body = bodyText;
  }

  return {
    status: response.status,
    ok: response.status >= 200 && response.status < 300,
    body,
  };
}

async function main() {
  console.log("== Test A: Function existence / anonymous access ==");
  const testA = await callHeatmapRpc({
    token: SUPABASE_PUBLISHABLE_KEY,
    userId: "00000000-0000-0000-0000-000000000000",
  });
  console.dir(testA, { depth: null });

  if (!USER_ACCESS_TOKEN || !USER_ID) {
    console.log("== Skip Test B/C ==");
    console.log("Set USER_ACCESS_TOKEN and USER_ID to run authenticated tests.");
    return;
  }

  console.log("== Test B: Happy path ==");
  const testB = await callHeatmapRpc({
    token: USER_ACCESS_TOKEN,
    userId: USER_ID,
  });
  console.dir(testB, { depth: null });

  console.log("== Test C: Unauthorized path ==");
  const testC = await callHeatmapRpc({
    token: USER_ACCESS_TOKEN,
    userId: "11111111-1111-1111-1111-111111111111",
  });
  console.dir(testC, { depth: null });
}

main().catch((error) => {
  console.error("RPC test failed:", error);
  process.exitCode = 1;
});
