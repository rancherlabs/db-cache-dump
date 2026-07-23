#!/usr/bin/env bash
set -euo pipefail

# Copies a SQLite DB from a via a kubectl debug container using the VACUUM INTO
# command, which makes it safe even for live DBs opened without durability options.
#
# The approach is possible because ephemeral containers have filesystem access to 
# the target container's filesystem via the `/proc/1/root` symlink.
#
# Unfortunately though, sqlite3 is not able to open database files in that location
# as-is, because it will canonicalize the symlink to `/` and fail.
#
# To work around that, this script copies sqlite3 and its shared library dependencies
# into a temporary directory, chroots into it and then runs sqlite3 with the correct
# library path.

# Usage:
#   safe-sqlite-copy.sh <db_path> <out_path>

DB_PATH=$1
OUT_PATH=$2 
TARGET_ROOT="/proc/1/root"
TEMP_DIR="/tmp/sqlite_env"

mkdir -p "${TARGET_ROOT}${TEMP_DIR}"

cleanup() {
  rm -rf "${TARGET_ROOT}${TEMP_DIR}"
}
trap cleanup EXIT

sqlite_bin="$(command -v sqlite3)"
cp "$sqlite_bin" "${TARGET_ROOT}${TEMP_DIR}/sqlite3"

# Copy shared library dependencies of sqlite3.
while IFS= read -r lib; do
  [[ -z "$lib" ]] && continue
  cp -L "$lib" "${TARGET_ROOT}${TEMP_DIR}/"
done < <(ldd "$sqlite_bin" | awk '/=> \/[^ ]+/ {print $3}')

# Copy dynamic loader
loader="$(ldd "$sqlite_bin" | awk '/ld-linux/ {print $1; exit}')"

if [[ -z "$loader" || ! -e "$loader" ]]; then
  echo "Could not locate dynamic loader for sqlite3" >&2
  exit 1
fi

loader_name="$(basename "$loader")"
cp -L "$loader" "${TARGET_ROOT}${TEMP_DIR}/${loader_name}"

# Run
chroot "$TARGET_ROOT" "${TEMP_DIR}/${loader_name}" \
  --library-path "$TEMP_DIR" \
  "${TEMP_DIR}/sqlite3" \
  "$DB_PATH" \
  "VACUUM INTO '$OUT_PATH';"
