#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=version.env
source "$project_dir/version.env"
if [[ -f $project_dir/version-local.env ]]; then
  # shellcheck source=/dev/null
  source "$project_dir/version-local.env"
fi

source_file="nginx-${NGINX_VERSION}.tar.gz"
source_path="$project_dir/downloads/$source_file"
mkdir -p "$project_dir/downloads"

if [[ ! -f $source_path ]]; then
  echo "Downloading https://nginx.org/download/$source_file"
  curl --fail --location --retry 3 --output "$source_path.part" \
    "https://nginx.org/download/$source_file"
  mv -- "$source_path.part" "$source_path"
fi

printf '%s  %s\n' "$NGINX_SHA256" "$source_path" | sha256sum --check --status || {
  echo "SHA-256 mismatch: $source_path" >&2
  exit 1
}
echo "Verified: $source_path"
