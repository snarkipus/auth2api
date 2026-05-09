#!/usr/bin/env sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-auth2api:local}"
CONTAINER_NAME="${CONTAINER_NAME:-auth2api}"
CONFIG_PATH="${CONFIG_PATH:-config.yaml}"
DATA_VOLUME="${DATA_VOLUME:-auth2api-data}"
HOST_BIND="${HOST_BIND:-127.0.0.1}"
HOST_PORT="${HOST_PORT:-8317}"
REMOVE_EXISTING="${REMOVE_EXISTING:-0}"

case "$CONFIG_PATH" in
  /*) ;;
  *) CONFIG_PATH="$PWD/$CONFIG_PATH" ;;
esac

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Config file not found: $CONFIG_PATH" >&2
  echo "Set CONFIG_PATH=/absolute/path/to/config.yaml if it is elsewhere." >&2
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  if [ "$REMOVE_EXISTING" = "1" ]; then
    docker rm -f "$CONTAINER_NAME" >/dev/null
  else
    echo "Container already exists: $CONTAINER_NAME" >&2
    echo "Run with REMOVE_EXISTING=1 to replace it, or remove it manually with: docker rm -f $CONTAINER_NAME" >&2
    exit 1
  fi
fi

docker volume create "$DATA_VOLUME" >/dev/null

docker run -d --name "$CONTAINER_NAME" \
  -p "$HOST_BIND:$HOST_PORT:8317" \
  -v "$DATA_VOLUME:/data" \
  -v "$CONFIG_PATH:/config/config.yaml:ro" \
  "$IMAGE_NAME"

echo "Started $CONTAINER_NAME from $IMAGE_NAME"
echo "Listening on http://$HOST_BIND:$HOST_PORT"
