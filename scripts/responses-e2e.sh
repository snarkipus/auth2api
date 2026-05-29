#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8317}"
CONFIG_PATH="${CONFIG_PATH:-config.yaml}"
MODEL="${MODEL:-gpt-5.5}"

if [ -z "${API_KEY:-}" ]; then
  if [ ! -f "$CONFIG_PATH" ]; then
    echo "API_KEY is required when CONFIG_PATH does not exist: $CONFIG_PATH" >&2
    exit 1
  fi

  API_KEY="$(awk -F'"' '/^api-keys:/ { in_keys=1; next } in_keys && /"/ { print $2; exit } in_keys && /^[^[:space:]-]/ { exit }' "$CONFIG_PATH")"
fi

if [ -z "$API_KEY" ]; then
  echo "Could not read an API key from $CONFIG_PATH; set API_KEY explicitly" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

non_stream_json="$TMP_DIR/non-stream.json"
stream_sse="$TMP_DIR/stream.sse"

curl -fsS "$BASE_URL/v1/responses" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"input\":\"Reply with exactly: auth2api ok\",\"max_output_tokens\":32}" \
  >"$non_stream_json"

node -e '
const fs = require("fs");
const response = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const text = (response.output || [])
  .flatMap((item) => item.content || [])
  .filter((part) => part.type === "output_text")
  .map((part) => part.text)
  .join("");
if (response.status !== "completed") {
  throw new Error(`Expected completed response, got ${response.status}`);
}
if (response.model !== process.argv[2]) {
  throw new Error(`Expected model ${process.argv[2]}, got ${response.model}`);
}
if (text !== "auth2api ok") {
  throw new Error(`Expected output "auth2api ok", got ${JSON.stringify(text)}`);
}
' "$non_stream_json" "$MODEL"

curl -fsS -N "$BASE_URL/v1/responses" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"input\":\"Reply with exactly: stream ok\",\"stream\":true,\"max_output_tokens\":32}" \
  >"$stream_sse"

grep -q '^event: response.created$' "$stream_sse"
grep -q '^event: response.output_text.delta$' "$stream_sse"
grep -q '^event: response.output_text.done$' "$stream_sse"
grep -q '^event: response.output_item.done$' "$stream_sse"
grep -q '^event: response.completed$' "$stream_sse"
grep -q '"text":"stream ok"' "$stream_sse"

echo "Responses e2e passed for $BASE_URL with $MODEL"
