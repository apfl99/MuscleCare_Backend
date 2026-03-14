#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   SUPABASE_MANAGEMENT_TOKEN=sbp_xxx \
#   SUPABASE_PROJECT_REF=ialgqpzyysctbtqrwyqq \
#   bash scripts/req30_apply_sql_via_management_api.sh

SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-ialgqpzyysctbtqrwyqq}"
SUPABASE_MANAGEMENT_TOKEN="${SUPABASE_MANAGEMENT_TOKEN:-}"
MANAGEMENT_API_BASE="https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/database/query"

if [[ -z "${SUPABASE_MANAGEMENT_TOKEN}" ]]; then
  echo "ERROR: SUPABASE_MANAGEMENT_TOKEN is required (format: sbp_...)."
  exit 1
fi

run_query_file() {
  local migration_name="$1"
  local sql_file="$2"

  if [[ ! -f "${sql_file}" ]]; then
    echo "ERROR: SQL file not found: ${sql_file}"
    exit 1
  fi

  local payload
  payload="$(python3 - "${migration_name}" "${sql_file}" <<'PY'
import json
import pathlib
import sys

name = sys.argv[1]
sql_path = pathlib.Path(sys.argv[2])
sql_text = sql_path.read_text(encoding="utf-8")

print(json.dumps({
    "name": name,
    "query": sql_text
}))
PY
)"

  echo "Applying ${sql_file} ..."
  local response
  response="$(
    curl -sS -w '\n%{http_code}' "${MANAGEMENT_API_BASE}" \
      --request POST \
      --header "Authorization: Bearer ${SUPABASE_MANAGEMENT_TOKEN}" \
      --header "Content-Type: application/json" \
      --data "${payload}"
  )"

  local http_code
  http_code="$(printf '%s' "${response}" | tail -n 1)"
  local body
  body="$(printf '%s' "${response}" | sed '$d')"

  printf '%s\n' "${body}"

  if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
    echo "ERROR: Management API returned HTTP ${http_code} for ${sql_file}"
    exit 1
  fi

  echo "Applied: ${sql_file}"
  echo
}

run_query_file "req30_heatmap_schema" "supabase/req30_heatmap_schema.sql"
run_query_file "req30_heatmap_seed" "supabase/req30_heatmap_seed.sql"

echo "Done."
