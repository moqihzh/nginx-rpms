#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=version.env
source "$project_dir/version.env"
if [[ -f $project_dir/version-local.env ]]; then
  # shellcheck source=/dev/null
  source "$project_dir/version-local.env"
fi

arch=$(rpm --eval '%{_arch}')
if [[ $arch != x86_64 && $arch != aarch64 ]]; then
  echo 'Supported architectures: x86_64, aarch64' >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo 'Cannot detect OS: /etc/os-release is missing' >&2
  exit 1
fi
# shellcheck source=/dev/null
source /etc/os-release

# Prints oe2003, oe2203, oe2403, el7, el8, or el9. EL rebuilds are
# recognized from %{dist} first, then from ID / ID_LIKE plus the major version.
detect_target() {
  case ${ID:-} in
    openEuler)
      case ${VERSION_ID:-} in
        20.03) printf '%s\n' oe2003; return 0 ;;
        22.03) printf '%s\n' oe2203; return 0 ;;
        24.03) printf '%s\n' oe2403; return 0 ;;
      esac
      ;;
  esac

  local rpm_dist
  rpm_dist=$(rpm --eval '%{?dist}' 2>/dev/null || true)
  rpm_dist=${rpm_dist#.}
  if [[ $rpm_dist =~ ^el([789])([^0-9]|$) ]]; then
    printf '%s\n' "el${BASH_REMATCH[1]}"
    return 0
  fi

  local like=" ${ID:-} ${ID_LIKE:-} "
  if [[ $like == *" rhel "* || $like == *" centos "* || $like == *" rocky "* || $like == *" almalinux "* || $like == *" ol "* ]]; then
    local major=${VERSION_ID:-}
    major=${major%%.*}
    case $major in
      7|8|9)
        printf '%s\n' "el${major}"
        return 0
        ;;
    esac
  fi
  return 1
}

usage() {
  echo 'Usage: ./compile.sh [oe2003|oe2203|oe2403|el7|el8|el9]' >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

requested=${1:-}
if ! detected=$(detect_target); then
  echo "Unsupported OS: ${PRETTY_NAME:-${ID:-unknown} ${VERSION_ID:-}}" >&2
  echo 'Supported: openEuler 20.03, 22.03, 24.03, EL7, EL8, EL9' >&2
  exit 1
fi

if [[ -n $requested ]]; then
  case $requested in
    oe20.03) requested=oe2003 ;;
    oe22.03) requested=oe2203 ;;
  esac
  case $requested in
    oe2003|oe2203|oe2403|el7|el8|el9) ;;
    *)
      usage
      exit 1
      ;;
  esac
  if [[ $requested != "$detected" ]]; then
    echo "This host is ${detected}; build ${requested} on that OS" >&2
    exit 1
  fi
fi
target=$detected

case $target in
  oe2003|oe2203|oe2403)
    release=$(rpm -q --qf '%{RELEASE}' openEuler-release)
    dist=${release##*.}
    case $target in
      # 20.03 GA used .oe1; service packs use .oe2003spN.
      oe2003) dist_re='^(oe1|oe2003(sp[0-9]+)?)$' ;;
      oe2203) dist_re='^oe2203(sp[0-9]+)?$' ;;
      oe2403) dist_re='^oe2403(sp[0-9]+)?$' ;;
    esac
    if [[ ! $dist =~ $dist_re ]]; then
      echo "Unexpected openEuler release tag: $dist" >&2
      exit 1
    fi
    ;;
  el7|el8|el9)
    # Keep the host tag (.el8, .el8_10, .ol8, ...) instead of forcing .elN.
    dist=$(rpm --eval '%{?dist}')
    dist=${dist#.}
    if [[ -z $dist ]]; then
      dist=$target
    fi
    ;;
esac

missing=0
if ! command -v rpmbuild >/dev/null 2>&1; then
  echo 'Missing command: rpmbuild' >&2
  missing=1
fi
if ! command -v gcc >/dev/null 2>&1; then
  echo 'Missing command: gcc' >&2
  missing=1
fi
if ! command -v make >/dev/null 2>&1; then
  echo 'Missing command: make' >&2
  missing=1
fi
if [[ $missing -ne 0 ]]; then
  case $target in
    el7)
      echo 'Install build dependencies: sudo yum install gcc make rpm-build redhat-rpm-config openssl-devel pcre-devel zlib-devel systemd curl cpio' >&2
      ;;
    el8|el9)
      echo 'Install build dependencies: sudo dnf install gcc make rpm-build redhat-rpm-config openssl-devel pcre2-devel zlib-devel systemd-rpm-macros curl cpio' >&2
      ;;
    oe2003|oe2203|oe2403)
      echo 'Install build dependencies: sudo dnf install gcc make rpm-build openssl-devel pcre2-devel zlib-devel curl cpio' >&2
      ;;
  esac
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

topdir="$project_dir/$target"
if [[ ! -f $topdir/SPECS/nginx.spec || ! -f $topdir/SOURCES/nginx.service ]]; then
  echo "Incomplete spec tree: $topdir" >&2
  exit 1
fi
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SRPMS} "$project_dir/output"
install -m 0644 "$source_path" "$topdir/SOURCES/$source_file"

echo "Building nginx ${NGINX_VERSION}-${PKGREL}.${dist} (${target}, ${arch})"

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
