#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
rpm_file=${1:-}
if [[ ! -f $rpm_file ]]; then
  echo "Usage: $0 path/to/nginx-binary.rpm" >&2
  exit 1
fi

work_dir=$(mktemp -d /tmp/nginx-rpm-smoke.XXXXXXXX)
trap 'rm -rf -- "$work_dir"' EXIT

rpm2cpio "$rpm_file" | (cd "$work_dir" && cpio -idm --quiet --no-preserve-owner)
mkdir -p "$work_dir/logs" "$work_dir/temp"

"$work_dir/usr/sbin/nginx" -v
"$work_dir/usr/sbin/nginx" -t \
  -p "$work_dir/" \
  -c "$project_dir/tests/nginx.conf" \
  -e stderr \
  -g 'user root;'
