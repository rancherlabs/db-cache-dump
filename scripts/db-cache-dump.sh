#!/usr/bin/env bash
set -euo pipefail

APP="${APP:-rancher}"
IMAGE="${IMAGE:-ghcr.io/rancherlabs/db-cache-dump:latest}"
OUT_DIR="${OUT_DIR:-./out}"

case "$APP" in
  rancher)
    NAMESPACE="cattle-system"
    CONTAINER="rancher"
    ;;
  cattle-cluster-agent)
    NAMESPACE="cattle-system"
    CONTAINER="cluster-register"
    ;;
  *)
    echo "Unsupported APP: $APP (expected rancher or cattle-cluster-agent)" >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR"
DB_PATH="/var/lib/rancher/informer_object_cache.db"
VACUUMED_NAME="vacuumed_informer_object_cache.db"

echo "==> Listing pods for app=$APP in namespace=$NAMESPACE"
pods=()
while IFS= read -r pod; do
  [[ -n "$pod" ]] && pods+=("$pod")
done < <(kubectl -n "$NAMESPACE" get pods -l "app=$APP" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [[ ${#pods[@]} -eq 0 ]]; then
  echo "No pods found for app=$APP in namespace=$NAMESPACE" >&2
  exit 1
fi

for pod in "${pods[@]}"; do
  [[ -z "$pod" ]] && continue
  local_out="${OUT_DIR}/${pod}-${VACUUMED_NAME}"

  echo "==> [$pod] Creating consistent sqlite snapshot via kubectl debug"
  kubectl -n "$NAMESPACE" debug "$pod" \
    --target="$CONTAINER" \
    --image="$IMAGE" \
    --profile=general \
    -- /usr/local/bin/safe-sqlite-copy.sh "$DB_PATH" "/tmp/${VACUUMED_NAME}"

  echo "==> [$pod] Waiting for /tmp/${VACUUMED_NAME} to appear in target container"
  for _ in $(seq 1 30); do
    if kubectl -n "$NAMESPACE" exec "$pod" -c "$CONTAINER" -- test -s "/tmp/${VACUUMED_NAME}"; then
      break
    fi
    sleep 1
  done
  kubectl -n "$NAMESPACE" exec "$pod" -c "$CONTAINER" -- test -s "/tmp/${VACUUMED_NAME}"

  echo "==> [$pod] Copying /tmp/${VACUUMED_NAME} to ${local_out}"
  kubectl -n "$NAMESPACE" cp --retries=10 -c "$CONTAINER" \
    "${pod}:/tmp/${VACUUMED_NAME}" "$local_out"
  test -s "$local_out"

  echo "==> [$pod] Cleaning up /tmp/${VACUUMED_NAME}"
  kubectl -n "$NAMESPACE" exec "$pod" -c "$CONTAINER" -- rm -f "/tmp/${VACUUMED_NAME}"

  echo "==> [$pod] Done: ${local_out}"
done
