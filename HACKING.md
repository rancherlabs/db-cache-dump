# Development Notes

## Design Principles

- **No unverified binaries in production pods**: sqlite3 is shipped in image run via `kubectl debug` and sourced from SLE BCI
- **Consistent snapshots**: `VACUUM INTO` creates a self-contained DB snapshot, even for live databases opened without durability options (as is the case for [Rancher's Vai SQLite cache database](https://github.com/rancher/steve/blob/38fad7297960dde262e19852aa1c738fc4255c86/pkg/sqlcache/db/client.go#L517-L518))
- **Works around `/proc/1/root` sqlite path canonicalization**: image includes a helper script  that stages sqlite + libs into target rootfs and runs sqlite inside `chroot`. That is because `sqlite3` from the debug container cannot directly open the db from `/proc` in the Rancher container due to path canonicalization (`/proc/1/root` is a symlink to `/`)

## Local development

```bash
make test        # docker build + smoke test
make test-e2e    # k3d end-to-end flow through scripts/db-cache-dump.sh
```
