#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8317}"

if [ -z "${API_KEY:-}" ]; then
  echo "API_KEY is required, for example:" >&2
  echo "  API_KEY=sk-... npm run docker:verify" >&2
  exit 1
fi

curl -fsS "$BASE_URL/health" >/dev/null
curl -fsS -H "Authorization: Bearer $API_KEY" "$BASE_URL/admin/accounts" >/dev/null
curl -fsS -H "Authorization: Bearer $API_KEY" "$BASE_URL/v1/models" >/dev/null

if [ "${VERIFY_CODEX:-0}" = "1" ]; then
  curl -fsS "$BASE_URL/v1/responses" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"gpt-5.5","input":"Reply with exactly: docker verify ok","stream":false}' >/dev/null
fi

echo "Docker service verification passed for $BASE_URL"
