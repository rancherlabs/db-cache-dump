# db-cache-dump

`db-cache-dump` is a minimal utility image and helper script for safely extracting
 a copy of Rancher's Vai SQLite cache database (`informer_object_cache.db`)
 from live pods.

## Usage

Point `KUBECONFIG` to your Rancher upstream or downstream cluster, then:

```bash
bash scripts/db-cache-dump.sh
```

Configuration via environment variables:
 - `APP`: `rancher` or `cattle-cluster-agent`
 - `IMAGE` (default: `ghcr.io/rancherlabs/db-cache-dump:latest`)
 - `OUT_DIR` (default: `./out`)
