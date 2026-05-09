#!/usr/bin/env sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-auth2api:docker-smoke}"
HOST_PORT="${HOST_PORT:-8317}"
API_KEY="${API_KEY:-sk-docker-smoke-test-key}"

TMP_DIR="$(mktemp -d)"
CONTAINER_ID=""

cleanup() {
  if [ -n "$CONTAINER_ID" ]; then
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP_DIR/config" "$TMP_DIR/auth"

cat >"$TMP_DIR/config/config.yaml" <<EOF
host: "0.0.0.0"
port: 8317
auth-dir: "/data"
api-keys:
  - "$API_KEY"
body-limit: "200mb"
debug: "off"
EOF

# Fake, non-secret token data is enough to let the server start and list static
# Anthropic models. The smoke test does not call upstream provider APIs.
cat >"$TMP_DIR/auth/claude-docker-smoke@example.com.json" <<EOF
{
  "access_token": "fake-access-token",
  "refresh_token": "fake-refresh-token",
  "last_refresh": "2099-01-01T00:00:00.000Z",
  "email": "docker-smoke@example.com",
  "type": "claude",
  "expired": "2099-01-01T00:00:00.000Z",
  "account_uuid": "docker-smoke"
}
EOF

chmod 755 "$TMP_DIR" "$TMP_DIR/config" "$TMP_DIR/auth"
chmod 644 "$TMP_DIR/config/config.yaml" "$TMP_DIR/auth/claude-docker-smoke@example.com.json"

docker build -t "$IMAGE_NAME" .

CONTAINER_ID="$(docker run -d --rm \
  -p "127.0.0.1:${HOST_PORT}:8317" \
  -v "$TMP_DIR/config/config.yaml:/config/config.yaml:ro" \
  -v "$TMP_DIR/auth:/data:ro" \
  "$IMAGE_NAME")"

health_url="http://127.0.0.1:${HOST_PORT}/health"
admin_url="http://127.0.0.1:${HOST_PORT}/admin/accounts"
models_url="http://127.0.0.1:${HOST_PORT}/v1/models"

i=0
until curl -fs "$health_url" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    docker logs "$CONTAINER_ID" >&2 || true
    echo "Timed out waiting for $health_url" >&2
    exit 1
  fi
  sleep 1
done

unauth_status="$(curl -sS -o /dev/null -w '%{http_code}' "$admin_url")"
if [ "$unauth_status" != "401" ]; then
  echo "Expected unauthenticated admin request to return 401, got $unauth_status" >&2
  exit 1
fi

curl -fsS -H "Authorization: Bearer $API_KEY" "$admin_url" >/dev/null
curl -fsS -H "Authorization: Bearer $API_KEY" "$models_url" >/dev/null

echo "Docker smoke test passed for $IMAGE_NAME on 127.0.0.1:$HOST_PORT"
