#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-ghcr.io/rancherlabs/db-cache-dump:dev}"

echo "==> Verifying sqlite3 is present"
docker run --rm "$IMAGE" --version

echo "==> Running VACUUM INTO smoke test"
docker run --rm "$IMAGE" :memory: \
  "CREATE TABLE t(k TEXT PRIMARY KEY, v TEXT); INSERT INTO t VALUES ('ok','1'); VACUUM INTO '/tmp/snapshot.db'; ATTACH DATABASE '/tmp/snapshot.db' AS snap; SELECT count(*) FROM snap.t;" \
  | grep -q '^1$'

echo "Smoke test passed"
