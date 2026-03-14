#!/usr/bin/env bash
set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-https://ialgqpzyysctbtqrwyqq.supabase.co}"
SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_tBWvZfUGmzEP9BJWcZCKMA_wFIXV6N1}"

# For authenticated tests:
# - USER_ACCESS_TOKEN: JWT token returned by Supabase Auth sign-in
# - USER_ID: auth.users.id
USER_ACCESS_TOKEN="${USER_ACCESS_TOKEN:-}"
USER_ID="${USER_ID:-}"

rpc_url="${SUPABASE_URL}/rest/v1/rpc/get_muscle_heatmap_status"

echo "== Test A: Function existence / anonymous access =="
curl -sS -i "${rpc_url}" \
  --request POST \
  --header "apikey: ${SUPABASE_PUBLISHABLE_KEY}" \
  --header "Authorization: Bearer ${SUPABASE_PUBLISHABLE_KEY}" \
  --header "Content-Type: application/json" \
  --data '{"p_user_id":"00000000-0000-0000-0000-000000000000"}'
echo

if [[ -z "${USER_ACCESS_TOKEN}" || -z "${USER_ID}" ]]; then
  echo "== Skip Test B/C =="
  echo "Set USER_ACCESS_TOKEN and USER_ID to run authenticated tests."
  exit 0
fi

echo "== Test B: Happy path (auth user_id == p_user_id) =="
curl -sS -i "${rpc_url}" \
  --request POST \
  --header "apikey: ${SUPABASE_PUBLISHABLE_KEY}" \
  --header "Authorization: Bearer ${USER_ACCESS_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "{\"p_user_id\":\"${USER_ID}\"}"
echo

echo "== Test C: Unauthorized path (auth user_id != p_user_id) =="
curl -sS -i "${rpc_url}" \
  --request POST \
  --header "apikey: ${SUPABASE_PUBLISHABLE_KEY}" \
  --header "Authorization: Bearer ${USER_ACCESS_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{"p_user_id":"11111111-1111-1111-1111-111111111111"}'
echo
