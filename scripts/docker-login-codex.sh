#!/usr/bin/env sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-auth2api:local}"
CONFIG_PATH="${CONFIG_PATH:-config.yaml}"
DATA_VOLUME="${DATA_VOLUME:-auth2api-data}"

case "$CONFIG_PATH" in
  /*) ;;
  *) CONFIG_PATH="$PWD/$CONFIG_PATH" ;;
esac

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Config file not found: $CONFIG_PATH" >&2
  echo "Set CONFIG_PATH=/absolute/path/to/config.yaml if it is elsewhere." >&2
  exit 1
fi

docker volume create "$DATA_VOLUME" >/dev/null

docker run --rm -it \
  -v "$DATA_VOLUME:/data" \
  -v "$CONFIG_PATH:/config/config.yaml:ro" \
  "$IMAGE_NAME" \
  node dist/index.js --config=/config/config.yaml --login --provider=codex --manual

echo "Codex token saved in Docker volume: $DATA_VOLUME"
echo "If the running auth2api server did not reload automatically, restart it with: docker restart auth2api"
