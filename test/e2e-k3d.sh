#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/rancherlabs/db-cache-dump:dev}"
POD_NAME="${POD_NAME:-rancher-e2e}"
K3D_API_PORT="${K3D_API_PORT:-6445}"

mkdir -p .tmp
export KUBECONFIG="$PWD/.tmp/kubeconfig.db-cache-dump-e2e.yaml"

cleanup() {
  k3d cluster delete db-cache-dump-e2e >/dev/null 2>&1 || true
}
trap cleanup EXIT

k3d cluster create db-cache-dump-e2e --wait --api-port "$K3D_API_PORT"
k3d kubeconfig get db-cache-dump-e2e > "$KUBECONFIG"
# HACK: Force IPv4 loopback to avoid localhost->::1 failures in some environments.
sed -i.bak 's#https://localhost:#https://127.0.0.1:#g' "$KUBECONFIG" && rm -f "$KUBECONFIG.bak"
k3d image import "$IMAGE" -c db-cache-dump-e2e

kubectl create namespace cattle-system
cat <<'EOF' | kubectl -n cattle-system apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rancher-e2e
  labels:
    app: rancher
spec:
  containers:
    - name: rancher
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF

kubectl -n cattle-system wait --for=condition=Ready pod/rancher-e2e --timeout=120s

kubectl -n cattle-system exec rancher-e2e -c rancher -- sh -lc "mkdir -p /var/lib/rancher"

mkdir -p .tmp
outdir="$(mktemp -d "$PWD/.tmp/e2e.XXXXXX")"
sqlite3 "$outdir/informer_object_cache.db" "CREATE TABLE t(x); INSERT INTO t VALUES (1);"
kubectl -n cattle-system cp -c rancher "$outdir/informer_object_cache.db" \
  "rancher-e2e:/var/lib/rancher/informer_object_cache.db"

APP=rancher IMAGE="$IMAGE" OUT_DIR="$outdir" bash scripts/db-cache-dump.sh

dump_file="$outdir/rancher-e2e-vacuumed_informer_object_cache.db"
test -f "$dump_file"

sqlite3 "$dump_file" "SELECT count(*) FROM t;" | tr -d '\r' | grep -q '^1$'

echo "E2E test passed"
