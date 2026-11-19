# nginx-rpms

English | [简体中文](README_CN.md)

Build upstream nginx RPMs for openEuler 20.03, 22.03, and 24.03, and for
Enterprise Linux 7, 8, and 9.
This project follows the `version.env` + `pullsrc.sh` + `compile.sh` +
per-distribution spec layout used by
[openssh-rpms](https://github.com/boypt/openssh-rpms).

`compile.sh` reads the host and selects the spec directory. RHEL, CentOS,
Rocky Linux, AlmaLinux, Oracle Linux, and other rebuilds that identify as EL
7, 8, or 9 use the matching `elN` spec. The release tag stays the host
`%{dist}` (`el8`, `el8_10`, `ol8`, and so on).

| Host | Spec directory |
| --- | --- |
| openEuler 20.03 LTS | `oe2003/` |
| openEuler 22.03 LTS | `oe2203/` |
| openEuler 24.03 LTS | `oe2403/` |
| EL7 | `el7/` |
| EL8 | `el8/` |
| EL9 | `el9/` |

Supported architectures are x86_64 and aarch64. The openEuler x86_64 build has
been tested on 24.03 LTS-SP4. Build the EL packages on a matching EL host.

## Layout

| Path | Purpose |
| --- | --- |
| `version.env` | Pinned nginx version, source SHA-256, RPM release |
| `version-local.env` | Optional local overrides, ignored by Git |
| `pullsrc.sh` | Download and verify the upstream source archive |
| `compile.sh` | Build binary, debug and source RPMs for the host |
| `oe2003/SPECS/nginx.spec` | openEuler 20.03 package |
| `oe2203/SPECS/nginx.spec` | openEuler 22.03 package |
| `oe2403/SPECS/nginx.spec` | openEuler 24.03 package |
| `el7/SPECS/nginx.spec` | Enterprise Linux 7 package |
| `el8/SPECS/nginx.spec` | Enterprise Linux 8 package |
| `el9/SPECS/nginx.spec` | Enterprise Linux 9 package |
| `*/SOURCES/nginx.service` | systemd service unit for that target |
| `downloads/`, `output/` | Source cache and generated packages, ignored by Git |

## Build

Install build dependencies on the host you are building for.

openEuler 20.03, 22.03, or 24.03:

```bash
sudo dnf install gcc make rpm-build openssl-devel pcre2-devel zlib-devel curl cpio
```

EL8 or EL9:

```bash
sudo dnf install gcc make rpm-build redhat-rpm-config openssl-devel pcre2-devel zlib-devel systemd-rpm-macros curl cpio
```

EL7.4 or later (OpenSSL 1.0.2):

```bash
sudo yum install gcc make rpm-build redhat-rpm-config openssl-devel pcre-devel zlib-devel systemd curl cpio
```

Then run:

```bash
./pullsrc.sh
./compile.sh
ls output/
./tests/smoke.sh output/nginx-1.31.9-1.el9.x86_64.rpm
```

`./compile.sh` with no arguments detects the host. `./compile.sh el9` selects
that spec when the host itself is EL9; the same form works for `oe2003`,
`oe2203`, `oe2403`, `el7`, and `el8`. `oe20.03` and `oe22.03` are accepted as
names for `oe2003` and `oe2203`. The 20.03 GA release tag is `.oe1`; its
service packs use `.oe2003spN`. Pass the binary RPM to the smoke test, using
the filename produced for your release tag and architecture. The test extracts the package
into a temporary directory and checks the nginx binary without installing it.

If the host cannot reach `nginx.org`, place the archive named in `version.env`
inside `downloads/`. Both scripts check its SHA-256 before use. To build a
different version, set `NGINX_VERSION`, `NGINX_SHA256` and optionally `PKGREL`
in `version-local.env`; the source URL and RPM version follow those values.

Every target links the system OpenSSL, zlib, and PCRE library, and enables
TLS, HTTP/2, stream proxying, PCRE JIT, and the common HTTP modules. HTTP/3 is
not enabled. EL8 and EL9 use PCRE2. EL7 base repositories ship PCRE 8, which
nginx 1.31 still accepts. EL7 OpenSSL 1.0.2 provides TLS 1.2; TLS 1.3 is
available on EL8 (OpenSSL 1.1.1), EL9 (OpenSSL 3), openEuler 20.03 and 22.03
(OpenSSL 1.1.1), and openEuler 24.03 (OpenSSL 3).

The `nginx`, `nginx-debuginfo`, and `nginx-debugsource` RPMs, plus the nginx
source RPM, are copied to `output/`. EL7 rpm produces debuginfo and does not
produce a separate debugsource package.

## Install

EL7:

```bash
sudo yum install ./output/nginx-1.31.9-1.el7.x86_64.rpm
```

EL8, EL9, and openEuler:

```bash
sudo dnf install ./output/nginx-1.31.9-1.el9.x86_64.rpm
```

Use the RPM filename produced for your release tag and architecture. On
openEuler, `nginx-mod-stream` and the other module packages require
`nginx(abi) = 1.24.0` and block the new package. An already built package
that has no Epoch can erase the conflicting packages:

```bash
sudo dnf install --allowerasing ./nginx-1.31.9-1.oe2403sp4.x86_64.rpm
```

A package rebuilt after this change has Epoch 1 and obsoletes those module
packages, so a plain `dnf install` replaces them. When the distribution nginx
is already installed on EL8 or EL9, disable the AppStream module and remove
its packages first. Otherwise a later update can replace this build, and the
split `nginx-filesystem` / `nginx-mod-*` packages can conflict on `/etc/nginx`:

```bash
sudo dnf module disable nginx
sudo dnf remove nginx nginx-filesystem nginx-all-modules
```

The EL packages use Epoch 1, the same epoch as the distribution and nginx.org
packages, so version 1.31 sorts as an upgrade. Install and upgrade run
`systemctl enable nginx`. A package already installed from a build that does
not do this needs it once:

```bash
sudo systemctl enable nginx
sudo nginx -t && sudo systemctl start nginx
```

The package creates the `nginx` service account, installs
`/etc/nginx/nginx.conf` as `%config(noreplace)`, and includes a systemd unit.
SSL, HTTP/2, and stream are compiled into the binary. A configuration kept
from the distribution package may still contain `load_module` or
`include /usr/share/nginx/modules/*.conf`; compare it with
`/etc/nginx/nginx.conf.rpmnew` and remove those lines before restarting.
firewalld can still block port 80. If SELinux denies the service, inspect the
audit log before changing the policy.

## License

The project scripts and packaging files are MIT licensed. nginx itself keeps
its upstream BSD-2-Clause license, included in the RPM.
