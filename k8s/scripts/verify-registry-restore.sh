#!/usr/bin/env bash
set -euo pipefail

archive="${1:?usage: verify-registry-restore.sh ARCHIVE RESTORE_DIRECTORY}"
restore_dir="${2:?usage: verify-registry-restore.sh ARCHIVE RESTORE_DIRECTORY}"

test ! -e "${restore_dir}"
mkdir "${restore_dir}"
tar -xzf "${archive}" -C "${restore_dir}"

test -s \
  "${restore_dir}/docker/registry/v2/repositories/phase-d/busybox/_manifests/tags/1.37.0/current/link"
blob_count="$(find "${restore_dir}/docker/registry/v2/blobs" -type f -name data | wc -l)"
test "${blob_count}" -ge 2
