%{!?nginxver: %global nginxver 1.31.9}
%{!?nginxpkgrel: %global nginxpkgrel 1}

Name:           nginx
# Epoch 1 matches openEuler nginx, so 1.31 replaces 1.24.
Epoch:          1
Version:        %{nginxver}
Release:        %{nginxpkgrel}%{?dist}
# Stream is compiled in. Drop the distro modules pinned to nginx(abi) = 1.24.0.
Obsoletes:      nginx-all-modules < 1:%{version}
Obsoletes:      nginx-mod-stream < 1:%{version}
Obsoletes:      nginx-mod-http-image-filter < 1:%{version}
Obsoletes:      nginx-mod-http-perl < 1:%{version}
Obsoletes:      nginx-mod-http-xslt-filter < 1:%{version}
Obsoletes:      nginx-mod-mail < 1:%{version}
Obsoletes:      nginx-mod-http-geoip < 1:%{version}
Obsoletes:      nginx-mod-devel < 1:%{version}
Summary:        High performance HTTP and reverse proxy server
License:        BSD-2-Clause
URL:            https://nginx.org/
Source0:        https://nginx.org/download/nginx-%{version}.tar.gz
Source1:        nginx.service
BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  openssl-devel
BuildRequires:  pcre2-devel
BuildRequires:  zlib-devel
Requires(pre):  shadow

%description
nginx is an HTTP and reverse proxy server and a generic TCP/UDP proxy server.

%prep
%autosetup -n nginx-%{version}

%build
./configure \
    --prefix=%{_datadir}/nginx \
    --sbin-path=%{_sbindir}/nginx \
    --modules-path=%{_libdir}/nginx/modules \
    --conf-path=%{_sysconfdir}/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/lock/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_auth_request_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt="%{optflags}" \
    --with-ld-opt="%{?build_ldflags}"
%make_build

%install
%make_install DESTDIR=%{buildroot}
install -Dpm 0644 objs/nginx.8 %{buildroot}%{_mandir}/man8/nginx.8
install -Dpm 0644 %{SOURCE1} %{buildroot}%{_unitdir}/nginx.service
install -d -m 0755 %{buildroot}%{_libdir}/nginx/modules
install -d -m 0755 %{buildroot}/var/log/nginx
install -d -m 0750 %{buildroot}/var/cache/nginx
install -d -m 0750 %{buildroot}/var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}

%pre
getent group nginx >/dev/null || groupadd -r nginx
getent passwd nginx >/dev/null || useradd -r -g nginx -d %{_datadir}/nginx -s /sbin/nologin -c "nginx web server" nginx

%post
%systemd_post nginx.service
# preset leaves nginx disabled. Enable it on install and upgrade.
systemctl enable nginx.service >/dev/null 2>&1 || :

%preun
%systemd_preun nginx.service

%postun
%systemd_postun_with_restart nginx.service

%files
%license LICENSE
%doc README.md
%{_sbindir}/nginx
%dir %{_libdir}/nginx
%dir %{_libdir}/nginx/modules
%{_datadir}/nginx/
%{_mandir}/man8/nginx.8*
%dir %{_sysconfdir}/nginx
%config(noreplace) %{_sysconfdir}/nginx/*
%{_unitdir}/nginx.service
%dir /var/log/nginx
%dir %attr(0750,nginx,nginx) /var/cache/nginx
%dir %attr(0750,nginx,nginx) /var/cache/nginx/client_temp
%dir %attr(0750,nginx,nginx) /var/cache/nginx/proxy_temp
%dir %attr(0750,nginx,nginx) /var/cache/nginx/fastcgi_temp
%dir %attr(0750,nginx,nginx) /var/cache/nginx/uwsgi_temp
%dir %attr(0750,nginx,nginx) /var/cache/nginx/scgi_temp

%changelog
* Thu Nov 19 2026 nginx-rpms contributors - 1.31.9-1
- Update to nginx 1.31.9
- Replace openEuler nginx-mod-* packages pinned to nginx(abi) = 1.24.0
- Enable nginx.service on install and upgrade

* Thu Nov 12 2026 nginx-rpms contributors - 1.31.8-1
- Initial openEuler 24.03 package
