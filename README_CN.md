# nginx-rpms

[English](README.md) | 简体中文

本项目为 openEuler 20.03、22.03、24.03 以及企业 Linux 7、8、9 构建上游 nginx RPM。目录结构参考
[openssh-rpms](https://github.com/boypt/openssh-rpms)，使用 `version.env` 管理版本，
`pullsrc.sh` 下载源码，`compile.sh` 构建软件包，并按目标系统存放 RPM spec。

`compile.sh` 根据当前主机选择 spec 目录。RHEL、CentOS、Rocky Linux、AlmaLinux、
Oracle Linux，以及其他标识为 EL7、EL8、EL9 的重构版，使用对应的 `elN` spec。
RPM 发布号保留主机自己的 `%{dist}`，例如 `el8`、`el8_10`、`ol8`。

| 主机 | spec 目录 |
| --- | --- |
| openEuler 20.03 LTS | `oe2003/` |
| openEuler 22.03 LTS | `oe2203/` |
| openEuler 24.03 LTS | `oe2403/` |
| EL7 | `el7/` |
| EL8 | `el8/` |
| EL9 | `el9/` |

支持 x86_64 和 aarch64。openEuler 的 x86_64 构建已在 24.03 LTS-SP4 上验证。
EL 软件包需要在对应的 EL 主机上构建。

## 项目结构

| 路径 | 用途 |
| --- | --- |
| `version.env` | 固定 nginx 版本、源码 SHA-256 和 RPM 发布号 |
| `version-local.env` | 可选的本地覆盖配置，不纳入 Git |
| `pullsrc.sh` | 下载并校验上游源码包 |
| `compile.sh` | 按当前主机构建二进制、调试和源码 RPM |
| `oe2003/SPECS/nginx.spec` | openEuler 20.03 打包定义 |
| `oe2203/SPECS/nginx.spec` | openEuler 22.03 打包定义 |
| `oe2403/SPECS/nginx.spec` | openEuler 24.03 打包定义 |
| `el7/SPECS/nginx.spec` | Enterprise Linux 7 打包定义 |
| `el8/SPECS/nginx.spec` | Enterprise Linux 8 打包定义 |
| `el9/SPECS/nginx.spec` | Enterprise Linux 9 打包定义 |
| `*/SOURCES/nginx.service` | 对应目标的 systemd 服务单元 |
| `downloads/`、`output/` | 源码缓存和构建产物，不纳入 Git |

## 构建

先在用来编译的主机上安装依赖。

openEuler 20.03、22.03 或 24.03：

```bash
sudo dnf install gcc make rpm-build openssl-devel pcre2-devel zlib-devel curl cpio
```

EL8 或 EL9：

```bash
sudo dnf install gcc make rpm-build redhat-rpm-config openssl-devel pcre2-devel zlib-devel systemd-rpm-macros curl cpio
```

EL7.4 及更新版本（系统 OpenSSL 为 1.0.2）：

```bash
sudo yum install gcc make rpm-build redhat-rpm-config openssl-devel pcre-devel zlib-devel systemd curl cpio
```

下载源码、构建 RPM，并检查包内的 nginx 程序：

```bash
./pullsrc.sh
./compile.sh
ls output/
./tests/smoke.sh output/nginx-1.31.8-1.el9.x86_64.rpm
```

不带参数的 `./compile.sh` 会识别主机。在 EL9 上可以执行 `./compile.sh el9`；
`oe2003`、`oe2203`、`oe2403`、`el7`、`el8` 同样如此。`oe20.03` 和 `oe22.03`
会分别对应 `oe2003`、`oe2203`。20.03 首个正式版的发布号是 `.oe1`，后续服务包是
`.oe2003spN`。smoke test 需要传入二进制 RPM，文件名换成
本次构建实际生成的发布号和架构。它把 RPM 解压到临时目录并检查其中的 nginx
程序，不安装到系统。

如果主机无法访问 `nginx.org`，可将 `version.env` 指定的源码压缩包放入
`downloads/`。两个脚本在使用源码前都会校验 SHA-256。构建其他版本时，在
`version-local.env` 中设置 `NGINX_VERSION`、`NGINX_SHA256`，并按需设置
`PKGREL`；源码下载地址与 RPM 版本号会随之更新。

各目标都链接系统提供的 OpenSSL、zlib 和 PCRE，启用 TLS、HTTP/2、stream 代理、
PCRE JIT 及常用 HTTP 模块；未启用 HTTP/3。EL8 和 EL9 使用 PCRE2。EL7 基础仓库
提供的是 PCRE 8，nginx 1.31 仍然支持。EL7 的 OpenSSL 1.0.2 提供 TLS 1.2。
EL8、openEuler 20.03 和 22.03 使用 OpenSSL 1.1.1，EL9 和 openEuler 24.03
使用 OpenSSL 3，这些系统都支持 TLS 1.3。

构建完成后，`output/` 中会有 `nginx`、`nginx-debuginfo`、`nginx-debugsource`
RPM 和源码 RPM。EL7 的 rpm 会生成 debuginfo，不会另外生成 debugsource 包。

## 安装

EL7：

```bash
sudo yum install ./output/nginx-1.31.8-1.el7.x86_64.rpm
```

EL8、EL9 和 openEuler：

```bash
sudo dnf install ./output/nginx-1.31.8-1.el9.x86_64.rpm
```

请使用本次构建得到的发布号和架构。EL8、EL9 上如果已经装过发行版 nginx，
先关闭 AppStream 模块并卸掉原来的包，否则之后的系统更新可能把它换回去，
拆分的 `nginx-filesystem`、`nginx-mod-*` 也可能和 `/etc/nginx` 冲突：

```bash
sudo dnf module disable nginx
sudo dnf remove nginx nginx-filesystem nginx-all-modules
```

EL 软件包的 Epoch 为 1，与发行版和 nginx.org 的软件包相同，因此 1.31 会被当成
升级。确认配置后启动服务：

```bash
sudo nginx -t
sudo systemctl enable --now nginx
```

软件包会创建 `nginx` 服务账号，以 `%config(noreplace)` 方式安装
`/etc/nginx/nginx.conf`，并提供 systemd 服务单元。SSL、HTTP/2 和 stream
已经编译进二进制。从发行版软件包留下的配置可能仍有 `load_module` 或
`include /usr/share/nginx/modules/*.conf`；重启前对照
`/etc/nginx/nginx.conf.rpmnew` 删掉这些行。firewalld 仍可能拦截 80 端口。
如果 SELinux 拒绝该服务，先查看审计日志，再决定是否调整策略。

## 许可证

本项目的脚本和打包文件采用 MIT 许可证；nginx 本身保留上游 BSD-2-Clause
许可证，该许可证随 RPM 一同提供。
