# Nginx pkg-oss RPM Build System Defaults

Reference documentation for how the upstream nginx/pkg-oss repository handles RPM package builds. This documents the **default** behavior before any Centmin Mod customization.

---

## Repository Structure (RPM-relevant)

```
pkg-oss/
├── rpm/
│   ├── SPECS/
│   │   ├── nginx.spec.in              # Main spec template
│   │   ├── nginx-module.spec.in       # Dynamic module spec template
│   │   ├── nginx-plus-module.spec.in  # NGINX Plus module spec
│   │   ├── nginx-release-rhel.spec    # RHEL repo package
│   │   ├── nginx-release-centos.spec  # CentOS repo package
│   │   ├── Makefile                   # Build orchestrator
│   │   └── Makefile.module-*          # 19 module-specific Makefiles
│   └── SOURCES/
│       ├── nginx.service              # Systemd service
│       ├── nginx-debug.service        # Debug systemd service
│       ├── nginx.conf                 # Default nginx.conf
│       ├── nginx.default.conf         # Default server block
│       ├── nginx.repo                 # YUM repo config
│       ├── logrotate                  # Logrotate config
│       ├── nginx.upgrade.sh           # Binary upgrade script
│       ├── nginx.check-reload.sh      # Config check script
│       └── RPM-GPG-KEY-nginx          # GPG signing key
├── contrib/src/                       # Module sources (23+ modules)
├── Makefile                           # Root version/release management
└── build_module.sh                    # Custom module packaging utility
```

---

## Spec File Templates

### nginx.spec.in (Base Package)

**Template Variables** (replaced at build time):
- `%%BASE_VERSION%%` → e.g., 1.29.7
- `%%BASE_RELEASE%%` → default: 1
- `%%PACKAGE_VENDOR%%` → NGINX Packaging <nginx-packaging@f5.com>
- `%%BASE_PATCHES%%` → auto-injected patch list
- `%%BASE_CONFIGURE_ARGS%%` → all --with-* flags

**Two builds per package**: release binary + debug binary (with `--with-debug`)

### nginx-module.spec.in (Dynamic Modules)

Generic template for all third-party dynamic modules. Key features:
- Requires base nginx: `Requires: nginx-r%{base_version}`
- Builds both debug and release `.so` files
- Supports META_MODULE (no-build dependency packages)

---

## Installation Paths

| Path | Purpose |
|------|---------|
| `/usr/sbin/nginx` | Main binary |
| `/usr/sbin/nginx-debug` | Debug binary |
| `/etc/nginx/` | Configuration directory |
| `/etc/nginx/nginx.conf` | Main config |
| `/etc/nginx/conf.d/` | Include directory |
| `/usr/lib/nginx/modules/` | Dynamic module directory |
| `/etc/nginx/modules` | Symlink → `../../usr/lib/nginx/modules` |
| `/var/cache/nginx/` | Cache directory |
| `/var/log/nginx/` | Log directory |
| `/var/run/nginx/` | PID/lock directory |
| `/usr/share/nginx/html/` | Default HTML content |

---

## Configure Flags (BASE_CONFIGURE_ARGS)

### Core Paths
```
--prefix=/etc/nginx
--sbin-path=/usr/sbin/nginx
--modules-path=/usr/lib64/nginx/modules
--conf-path=/etc/nginx/nginx.conf
--error-log-path=/var/log/nginx/error.log
--http-log-path=/var/log/nginx/access.log
--pid-path=/var/run/nginx.pid
--lock-path=/var/run/nginx.lock
```

### Temp Paths
```
--http-client-body-temp-path=/var/cache/nginx/client_temp
--http-proxy-temp-path=/var/cache/nginx/proxy_temp
--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp
--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp
--http-scgi-temp-path=/var/cache/nginx/scgi_temp
```

### User/Group
```
--user=nginx
--group=nginx
```

### Core Features
```
--with-compat                      # Module ABI compatibility
--with-file-aio                    # Async file I/O
--with-threads                     # Thread pool support
```

### HTTP Modules (all static/built-in)
```
--with-http_addition_module
--with-http_auth_request_module
--with-http_dav_module
--with-http_flv_module
--with-http_gunzip_module
--with-http_gzip_static_module
--with-http_mp4_module
--with-http_random_index_module
--with-http_realip_module
--with-http_secure_link_module
--with-http_slice_module
--with-http_ssl_module
--with-http_stub_status_module
--with-http_sub_module
--with-http_v2_module
--with-http_v3_module              # RHEL 8+ only
```

### Mail Modules
```
--with-mail
--with-mail_ssl_module
```

### Stream Modules
```
--with-stream
--with-stream_realip_module
--with-stream_ssl_module
--with-stream_ssl_preread_module
```

---

## Compiler & Linker Flags

```
WITH_CC_OPT = $(echo %{optflags} $(pcre2-config --cflags)) -fPIC
WITH_LD_OPT = -Wl,-z,relro -Wl,-z,now -pie
```

**Security hardening**:
- `-fPIC` — Position-independent code
- `-Wl,-z,relro` — Read-only relocations
- `-Wl,-z,now` — No lazy binding
- `-pie` — Position-independent executable
- Fedora: `%global _hardened_build 1`

---

## Distribution-Specific Handling

### Version Detection Macros
```
%{?rhel}           # RHEL/CentOS/AlmaLinux/Rocky version (7, 8, 9, 10)
%{?amzn}           # Amazon Linux version (2, 2023)
%{?suse_version}   # SUSE version (1315, 1500, 1600)
%{?fedora}         # Fedora presence
%{?dist}           # Distribution tag (.el7, .el8, .el9, .el10)
```

### Per-Version Differences

| Feature | RHEL 7 | RHEL 8 | RHEL 9 | RHEL 10 |
|---------|--------|--------|--------|---------|
| Epoch | 1 | 1 | 2 | 2 |
| OpenSSL pkg | openssl-devel >= 1.0.2 | openssl-devel >= 1.1.1 | openssl-devel | openssl-devel |
| HTTP/3 | No | Yes | Yes | Yes |
| Debug source | Yes | Disabled | Disabled | Disabled |
| PCRE | pcre2-devel | pcre2-devel | pcre2-devel | pcre2-devel |

### Amazon Linux 2 Special Handling
- Uses `openssl11-devel >= 1.1.1` (not system openssl-devel)
- ACME module: custom `OPENSSL_LIB_DIR=/usr/lib64/` and `OPENSSL_INCLUDE_DIR=/usr/include/`

---

## Build Dependencies

### Base Package (all versions)
```
BuildRequires: systemd
BuildRequires: zlib-devel
BuildRequires: pcre2-devel
BuildRequires: openssl-devel  # varies by OS (see table above)
```

### Runtime Dependencies
```
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd
Requires(pre): shadow-utils
Requires: procps-ng
Requires: openssl (version-specific)
```

---

## Module System

### Base Modules (built with core nginx)
```
BASE_MODULES = acme geoip image-filter njs otel perl xslt
```

### All Available Modules (19 total)
```
MODULES = acme auth-spnego brotli encrypted-session fips-check geoip
          geoip2 headers-more lua ndk njs otel passenger perl rtmp
          set-misc subs-filter xslt image-filter
```

### Module-Specific Build Requirements

| Module | BuildRequires | Notes |
|--------|---------------|-------|
| njs | libedit-devel, libxml2-devel, libxslt-devel, which, libatomic (EL8+) | Includes QuickJS, njs CLI |
| brotli | brotli-devel | |
| lua | (self-contained: builds LuaJIT) | Requires NDK, excludes ppc64le/s390x |
| otel | cmake, pkgconfig(re2), pkgconfig(libcares) | Builds abseil, protobuf, grpc, otel-cpp. Excluded on EL7 |
| acme | clang | Rust-based, vendored Cargo deps |
| perl | perl-devel, perl-ExtUtils-Embed | |
| xslt | libxslt-devel | |
| image-filter | gd-devel | |
| geoip | GeoIP-devel | Excluded EL8+ |
| geoip2 | libmaxminddb-devel | |
| ndk | (none) | Dependency for lua, set-misc, encrypted-session |
| headers-more | (none) | |
| auth-spnego | krb5-devel | |
| rtmp | (none) | |
| subs-filter | (none) | |
| passenger | rubygem(rake) | |
| fips-check | (none) | OpenSSL 3.0 patch |
| set-misc | (none) | Requires NDK |
| encrypted-session | (none) | Requires NDK |

### Module Dependencies
- **lua** → requires ndk
- **set-misc** → requires ndk
- **encrypted-session** → requires ndk

---

## OpenSSL/Crypto Handling

**pkg-oss uses system OpenSSL only** — no custom crypto library compilation.

| RHEL Version | OpenSSL Package | Min Version |
|--------------|-----------------|-------------|
| RHEL 7 | openssl-devel | >= 1.0.2 |
| RHEL 7 (Amazon 2) | openssl11-devel | >= 1.1.1 |
| RHEL 8 | openssl-devel | >= 1.1.1 |
| RHEL 9 | openssl-devel | (system default, 3.x) |
| RHEL 10 | openssl-devel | (system default, 3.x) |

No support for BoringSSL, AWS-LC, or LibreSSL.

---

## Patch System

Patches are collected from `contrib/src/*/` during spec generation and applied as `Patch001`, `Patch002`, etc.

**Known patches**:
- LuaJIT: Makefile.patch, luaconf.h.patch
- Lua modules: config.patch, proxy-ssl-verifyby.patch
- QuickJS: makefile.patch
- gRPC: cmake-no-re2.patch
- abseil-cpp: 2 bug fix patches
- Passenger: build-nginx.rb.patch, ContentHandler.c.patch
- FIPS check: OpenSSL 3.0 support patch

---

## RPM Packages Produced

### Base Package
- `nginx-{version}-{release}.el{N}.ngx.{arch}.rpm` — main binary + debug binary + configs
- `nginx-debuginfo-{version}-{release}.el{N}.ngx.{arch}.rpm` — debug symbols

### Module Packages (19)
- `nginx-module-acme`
- `nginx-module-auth-spnego`
- `nginx-module-brotli`
- `nginx-module-encrypted-session`
- `nginx-module-fips-check`
- `nginx-module-geoip`
- `nginx-module-geoip2`
- `nginx-module-headers-more`
- `nginx-module-image-filter`
- `nginx-module-lua`
- `nginx-module-ndk`
- `nginx-module-njs`
- `nginx-module-otel`
- `nginx-module-passenger`
- `nginx-module-perl`
- `nginx-module-rtmp`
- `nginx-module-set-misc`
- `nginx-module-subs-filter`
- `nginx-module-xslt`

### Repository Package
- `nginx-release-rhel` or `nginx-release-centos` — YUM repo config + GPG key

---

## Build Targets (Makefile)

```makefile
make all             # Build base + base modules
make base            # Build nginx core only
make base-modules    # Build 8 base modules
make modules         # Build all external modules
make module-<name>   # Build specific module
make list            # Show versions
make test            # Run tests (regular)
make test-debug      # Run tests (debug)
make clean           # Clean artifacts
```

---

## Version Management

**Version source**: `contrib/src/nginx/version`
```
NGINX_VERSION := 1.29.7
NGINX_PLUS_VERSION := 36
```

**Release format**: `{BASE_RELEASE}%{?dist}.ngx` (e.g., `1.el9.ngx`)

**Epoch**: RHEL 7-8 = 1, RHEL 9-10 = 2

---

## Key Files for Modification

| File | Purpose | Priority |
|------|---------|----------|
| `rpm/SPECS/nginx.spec.in` | Main spec template — paths, deps, configure args | Critical |
| `rpm/SPECS/Makefile` | Build orchestrator — versions, modules, flags | Critical |
| `rpm/SPECS/Makefile.module-*` | Per-module build configs | High |
| `rpm/SOURCES/nginx.conf` | Default nginx.conf | High |
| `rpm/SOURCES/nginx.default.conf` | Default server block | High |
| `rpm/SOURCES/nginx.service` | Systemd service file | Medium |
| `contrib/src/nginx/version` | Version definitions | Medium |
| `build_module.sh` | Custom module packaging utility | Reference |
