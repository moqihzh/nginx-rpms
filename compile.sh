#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=version.env
source "$project_dir/version.env"
if [[ -f $project_dir/version-local.env ]]; then
  # shellcheck source=/dev/null
  source "$project_dir/version-local.env"
fi

if [[ $(rpm --eval '%{_arch}') != x86_64 && $(rpm --eval '%{_arch}') != aarch64 ]]; then
  echo 'Supported architectures: x86_64, aarch64' >&2
  exit 1
fi

# The first spec targets the openEuler 24.03 ABI and systemd layout.
# shellcheck source=/dev/null
source /etc/os-release
if [[ $ID != openEuler || $VERSION_ID != 24.03 ]]; then
  echo "Unsupported OS: ${PRETTY_NAME:-$ID $VERSION_ID}; supported: openEuler 24.03" >&2
  exit 1
fi

release=$(rpm -q --qf '%{RELEASE}' openEuler-release)
dist=${release##*.}
if [[ ! $dist =~ ^oe2403(sp[0-9]+)?$ ]]; then
  echo "Unexpected openEuler release tag: $dist" >&2
  exit 1
fi

source_file="nginx-${NGINX_VERSION}.tar.gz"
source_path="$project_dir/downloads/$source_file"
if [[ ! -f $source_path ]]; then
  echo "Missing $source_path; run ./pullsrc.sh first" >&2
  exit 1
fi
printf '%s  %s\n' "$NGINX_SHA256" "$source_path" | sha256sum --check --status || {
  echo "SHA-256 mismatch: $source_path" >&2
  exit 1
}

topdir="$project_dir/oe2403"
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SRPMS} "$project_dir/output"
install -m 0644 "$source_path" "$topdir/SOURCES/$source_file"

# /var/tmp may be read-only in isolated build environments.
tmpdir=$(mktemp -d /tmp/nginx-rpmbuild.XXXXXXXX)
trap 'rm -rf -- "$tmpdir"' EXIT

rpmbuild -ba "$topdir/SPECS/nginx.spec" \
  --define "_topdir $topdir" \
  --define "_tmppath $tmpdir" \
  --define "nginxver $NGINX_VERSION" \
  --define "nginxpkgrel $PKGREL" \
  --define "dist .$dist"

find "$topdir/RPMS" "$topdir/SRPMS" -type f \
  -name "nginx*-${NGINX_VERSION}-${PKGREL}.${dist}.*.rpm" \
  -exec install -m 0644 -t "$project_dir/output" {} +
echo "RPMs: $project_dir/output"
