# nginx-rpms

[English](README.md) | 简体中文

本项目为 openEuler 24.03 构建上游 nginx RPM，目录结构参考
[openssh-rpms](https://github.com/boypt/openssh-rpms)，使用 `version.env` 管理版本，
`pullsrc.sh` 下载源码，`compile.sh` 构建软件包，并按目标系统存放 RPM spec。

当前支持 openEuler 24.03 LTS 的 x86_64 和 aarch64 架构。其中 x86_64 已在
24.03 LTS-SP4 上完成构建验证；其他服务包版本和 aarch64 可由脚本构建，尚未验证。

## 项目结构

| 路径 | 用途 |
| --- | --- |
| `version.env` | 固定 nginx 版本、源码 SHA-256 和 RPM 发布号 |
| `version-local.env` | 可选的本地覆盖配置，不纳入 Git |
| `pullsrc.sh` | 下载并校验上游源码包 |
| `compile.sh` | 在 openEuler 24.03 上构建二进制、调试和源码 RPM |
| `oe2403/SPECS/nginx.spec` | RPM 打包定义 |
| `oe2403/SOURCES/nginx.service` | systemd 服务单元 |
| `downloads/`、`output/` | 源码缓存和构建产物，不纳入 Git |

## 构建

在 openEuler 24.03 主机上安装依赖：

```bash
sudo dnf install gcc make rpm-build openssl-devel pcre2-devel zlib-devel curl cpio
```

下载源码、构建 RPM，并检查包内的 nginx 程序：

```bash
./pullsrc.sh
./compile.sh
ls output/
./tests/smoke.sh output/nginx-1.31.8-1.oe2403sp4.x86_64.rpm
```

如果主机无法访问 `nginx.org`，可将 `version.env` 指定的源码压缩包放入
`downloads/`。两个脚本在使用源码前都会校验 SHA-256。构建其他版本时，在
`version-local.env` 中设置 `NGINX_VERSION`、`NGINX_SHA256`，并按需设置
`PKGREL`；源码下载地址与 RPM 版本号会随之更新。

构建使用系统提供的 OpenSSL、PCRE2 和 zlib，启用 TLS、HTTP/2、stream 代理、
PCRE JIT 及常用 HTTP 模块；目前未启用 HTTP/3。构建完成后，`output/` 中会有
`nginx`、`nginx-debuginfo`、`nginx-debugsource` RPM 和源码 RPM。smoke test 会将
RPM 解压到临时目录并检查其中的 nginx 程序，无需安装到系统。

## 安装

```bash
sudo dnf install ./output/nginx-1.31.8-1.oe2403sp4.x86_64.rpm
sudo nginx -t
sudo systemctl enable --now nginx
```

请根据实际服务包版本和架构选择对应的 RPM 文件名。软件包会创建 `nginx` 服务
账号，以 `%config(noreplace)` 方式安装 `/etc/nginx/nginx.conf`，并提供 systemd
服务单元。从其他 nginx 软件包升级时，可能需要检查
`/etc/nginx/nginx.conf.rpmnew`；重启服务前应测试保留的配置。

## 许可证

本项目的脚本和打包文件采用 MIT 许可证；nginx 本身保留上游 BSD-2-Clause
许可证，该许可证随 RPM 一同提供。
