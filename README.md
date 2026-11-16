# nginx-rpms

Build upstream nginx RPMs for openEuler 24.03. This project follows the
`version.env` + `pullsrc.sh` + `compile.sh` + per-distribution spec layout used
by [openssh-rpms](https://github.com/boypt/openssh-rpms).

The first supported target is openEuler 24.03 LTS, x86_64 or aarch64. The
x86_64 build has been tested on 24.03 LTS-SP4. Other service packs and aarch64
are supported by the build scripts but have not yet been validated.

## Layout

| Path | Purpose |
| --- | --- |
| `version.env` | Pinned nginx version, source SHA-256, RPM release |
| `version-local.env` | Optional local overrides, ignored by Git |
| `pullsrc.sh` | Download and verify the upstream source archive |
| `compile.sh` | Build binary, debug and source RPMs on openEuler 24.03 |
| `oe2403/SPECS/nginx.spec` | RPM package definition |
| `oe2403/SOURCES/nginx.service` | systemd service unit |
| `downloads/`, `output/` | Source cache and generated packages, ignored by Git |

## Build

Install build dependencies on an openEuler 24.03 host:

```bash
sudo dnf install gcc make rpm-build openssl-devel pcre2-devel zlib-devel curl cpio
```

Then run:

```bash
./pullsrc.sh
./compile.sh
ls output/
./tests/smoke.sh output/nginx-1.31.8-1.oe2403sp4.x86_64.rpm
```

If the host cannot reach `nginx.org`, place the archive named in `version.env`
inside `downloads/`. Both scripts check its SHA-256 before use. To build a
different version, set `NGINX_VERSION`, `NGINX_SHA256` and optionally `PKGREL`
in `version-local.env`; the source URL and RPM version follow those values.

The build uses the system OpenSSL, PCRE2 and zlib libraries, and enables TLS,
HTTP/2, stream proxying, PCRE JIT and common HTTP modules. HTTP/3 is not
enabled. The `nginx`, `nginx-debuginfo` and `nginx-debugsource` RPMs, plus the
nginx source RPM, are copied to `output/`. The smoke test extracts the RPM into
a temporary directory and checks the packaged binary without installing it.

## Install

```bash
sudo dnf install ./output/nginx-1.31.8-1.oe2403sp4.x86_64.rpm
sudo nginx -t
sudo systemctl enable --now nginx
```

Use the RPM filename produced for your own service pack and architecture. The
package creates the `nginx` service account, installs `/etc/nginx/nginx.conf`
as `%config(noreplace)`, and includes a systemd unit. Upgrading from another
nginx package may require checking `/etc/nginx/nginx.conf.rpmnew` and testing
the retained configuration before restarting the service.

## License

The project scripts and packaging files are MIT licensed. nginx itself keeps
its upstream BSD-2-Clause license, included in the RPM.
