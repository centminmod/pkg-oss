# Centmin Mod Nginx Source Compilation Reference

Ultra-detailed documentation of how Centmin Mod (141.00beta01) source-compiles Nginx. Reference codebase at `/Users/george/D7378/PC/gitrepos/www_git/centminmod-claudecode` (READ-ONLY).

---

## Key Build Files

| File | Lines | Purpose |
|------|-------|---------|
| `inc/nginx_configure.inc` | 6,774 | Primary compilation engine — all configure flags |
| `inc/nginx_install.inc` | 647 | Installation workflow, user/group, systemd |
| `inc/nginx_upgrade.inc` | 999 | 9-phase upgrade process |
| `inc/nginx_modules.inc` | 43 | Third-party module downloading |
| `inc/nginx_patch.inc` | ~1,400 | Security/performance patches |
| `centmin.sh` | ~4,400 | Main interactive installer (menu-driven) |
| `example/custom_config.inc` | 6,015 | **575 documented variables** across 53 categories |

**Persistent user config**: `/etc/centminmod/custom_config.inc` (survives upgrades)

---

## Installation Paths (vs pkg-oss)

| Purpose | Centmin Mod | pkg-oss Default |
|---------|-------------|-----------------|
| Binary | `/usr/local/sbin/nginx` | `/usr/sbin/nginx` |
| Prefix | `/usr/local/nginx` | `/etc/nginx` |
| Config | `/usr/local/nginx/conf/nginx.conf` | `/etc/nginx/nginx.conf` |
| Modules | `/usr/local/nginx/modules/` | `/usr/lib/nginx/modules/` |
| Logs | `/usr/local/nginx/logs/` | `/var/log/nginx/` |
| Dependencies | `/usr/local/nginx-dep/` | (system paths) |
| Custom OpenSSL | `/opt/openssl/` | N/A (system only) |
| QUIC OpenSSL | `/opt/openssl-quic/` | N/A |
| Build directory | `/svr-setup/nginx-${NGINX_VERSION}/` | rpmbuild BUILDROOT |

---

## Nginx Version Defaults

```bash
NGINX_VERSION='1.29.7'
FREENGINX_VERSION='1.29.6'         # Maxim Dounin's fork
FREENGINX_INSTALL='n'              # Use official nginx by default
NGINX_ANGIE_VERSION='Angie-1.11.4' # Alternative fork
```

---

## Crypto Library Support (Mutually Exclusive)

Centmin Mod supports **4 crypto libraries** (pkg-oss only supports system OpenSSL):

### A. OpenSSL (Default)
```bash
OPENSSL_VERSION='1.1.1w'
OPENSSL_QUIC_VERSION='OpenSSL_1_1_1w+quic'
OPENSSL_CUSTOMPATH='/opt/openssl'
OPENSSL_SYSTEM_USE='n'              # Force custom compilation
OPENSSL_TLSONETHREE='y'             # TLSv1.3 support
OPENSSL_THREADS='y'                 # Threading support
CLOUDFLARE_PATCHSSL='n'             # ChaCha20 patch
```

### B. BoringSSL
```bash
BORINGSSL_SWITCH='n'                # Override to enable
BORINGSSL_SHARED='y'                # Shared library
BORINGSSL_DIR="/opt"
```
- Disables: lua-stream modules, LTO compilation

### C. AWS-LC (Amazon's Crypto Library)
```bash
AWS_LC_SWITCH='n'                   # Override to enable
AWS_LC_VERSION='v1.60.0'
AWS_LC_DIR="/opt"
```
- Highest priority for EL8/9/10
- Disables: QUIC support, lua-stream modules

### D. LibreSSL
```bash
LIBRESSL_SWITCH='n'                 # Override to enable
LIBRESSL_VERSION='3.9.2'
```
- Disables: lua-stream modules, system OpenSSL

### Mutual Exclusivity Logic (nginx_configure.inc)
```
LibreSSL=y  → OPENSSL_SYSTEM_USE=n
BoringSSL=y → OPENSSL_SYSTEM_USE=n
QUIC=y      → OPENSSL_SYSTEM_USE=n
AWS_LC=y    → OPENSSL_SYSTEM_USE=n, NGINX_QUIC_SUPPORT=n
```

---

## HTTP/2 & HTTP/3 (QUIC) Support

```bash
NGINX_HTTP2='y'                     # --with-http_v2_module
NGINX_QUIC_SUPPORT='y'             # --with-http_v3_module (nginx 1.25.0+)
NGINX_QUIC_DEBUG='n'
NGINX_QUIC_HPACK_SUPPORT='y'       # HPACK full encoding
NGINX_QUIC_RPMS='y'                # Use pre-built RPMs for QUIC OpenSSL
NGINX_HPACK='y'                    # --with-http_v2_hpack_enc (nginx ≤ 1.24)
```

---

## Compression Libraries

### Cloudflare Zlib (Default)
```bash
CLOUDFLARE_ZLIB='y'
CLOUDFLARE_ZLIB_DYNAMIC='y'
CLOUDFLARE_ZLIBVER='1.3.3'
```

### Zlib-ng (Alternative)
```bash
NGINX_ZLIBNG='n'                    # Takes priority over Cloudflare zlib
```

### Brotli
```bash
NGINX_LIBBROTLI='n'                # Dynamic module
NGINX_LIBBROTLISTATIC='n'          # Static pre-compress only
NGXDYNAMIC_BROTLI='y'              # Dynamic module default
```

### Zstandard
```bash
NGINX_ZSTD='n'
NGXDYNAMIC_ZSTD='n'
```

---

## Static HTTP Modules

### Default Enabled
```bash
NGINX_REALIP='y'                   # --with-http_realip_module
NGINX_GEOIP='y'                    # --with-http_geoip_module (or geoip2)
NGINX_STUBSTATUS='y'               # --with-http_stub_status_module
NGINX_SUB='y'                      # --with-http_sub_module
NGINX_ADDITION='y'                 # --with-http_addition_module
NGINX_IMAGEFILTER='y'              # --with-http_image_filter_module
NGINX_SECURELINK='y'               # --with-http_secure_link_module
NGINX_FANCYINDEX='y'               # --add-module=../ngx-fancyindex
NGINX_CACHEPURGE='y'               # --add-module=../ngx_cache_purge
NGINX_THREADS='y'                  # --with-threads
```

### Default Disabled (Optional)
```bash
NGINX_AUTHREQ='n'                  # --with-http_auth_request_module
NGINX_FLV='n'                      # --with-http_flv_module
NGINX_MP4='n'                      # --with-http_mp4_module
NGINX_PERL='n'                     # --with-http_perl_module
NGINX_XSLT='n'                     # --with-http_xslt_module
NGINX_RTMP='n'                     # --add-module=../nginx-rtmp-module
NGINX_WEBDAV='n'                   # --with-http_dav_module + dav-ext
NGINX_HTTPCONCAT='n'               # --add-module=../nginx-http-concat
NGINX_ACCESSKEY='n'                # --add-module=../nginx-accesskey
NGINX_LENGTHHIDE='n'               # --add-module=../nginx-length-hiding
NGINX_TESTCOOKIE='n'               # --add-module=../testcookie-nginx-module
NGINX_UPSTREAMCHECK='n'            # --add-module=../nginx_upstream_check_module
NGINX_STICKY='n'                   # --add-module=../nginx-sticky-module-ng
NGINX_RDNS='n'                     # --add-module=../nginx-http-rdns
NGINX_SLICE='n'                    # --with-http_slice_module
```

---

## Stream Modules

```bash
NGINX_STREAM='y'                   # --with-stream
NGINX_STREAMGEOIP='y'              # --with-stream_geoip_module
NGINX_STREAMREALIP='y'             # --with-stream_realip_module
NGINX_STREAMSSLPREREAD='y'         # --with-stream_ssl_preread_module
```

---

## Dynamic Module System

```bash
DYNAMIC_SUPPORT='y'                # Master switch (nginx 1.11.5+)
NGXDYNAMIC_MANUALOVERRIDE='n'      # Preserve manually-added modules
```

### Modules Compiled as Dynamic .so
```bash
NGXDYNAMIC_IMAGEFILTER='y'
NGXDYNAMIC_HEADERSMORE='y'
NGXDYNAMIC_SETMISC='y'
NGXDYNAMIC_ECHO='y'
NGXDYNAMIC_LUA='y'
NGXDYNAMIC_DEVELKIT='y'
NGXDYNAMIC_BROTLI='y'
NGXDYNAMIC_FANCYINDEX='y'
NGXDYNAMIC_HIDELENGTH='y'
NGXDYNAMIC_NJS='n'
NGXDYNAMIC_GEOIP='n'
NGXDYNAMIC_STREAM='n'
NGXDYNAMIC_STREAMGEOIP='n'
NGXDYNAMIC_STREAMREALIP='n'
NGXDYNAMIC_MEMC='n'
NGXDYNAMIC_REDISTWO='n'
NGXDYNAMIC_SRCCACHE='n'
NGXDYNAMIC_ZSTD='n'
```

**Module storage**: `/usr/local/nginx/modules/`
**Auto-loading**: `/usr/local/nginx/conf/dynamic-modules.conf`

---

## OpenResty / Lua Modules

```bash
# Headers More (most popular)
ORESTY_HEADERSMORE='y'
NGXDYNAMIC_HEADERSMORE='y'

# Lua Scripting
ORESTY_LUANGINX='n'               # Lua HTTP module
ORESTY_LUANGINXVER='0.10.28'
ORESTY_LUASTREAM='y'              # Stream Lua
ORESTY_LUAUPSTREAM='y'            # Upstream Lua
LUAJIT_GITINSTALL='y'             # LuaJIT 2.1 dev branch

# Set-Misc
ORESTY_SETMISC='y'
NGXDYNAMIC_SETMISC='y'

# Echo
ORESTY_ECHOVER='0.63'
NGXDYNAMIC_ECHO='y'

# Development Kit
ORESTY_DEVELKITVER='0.3.2'
NGXDYNAMIC_DEVELKIT='y'

# Memcache/Redis/Caching
NGXDYNAMIC_MEMC='n'
NGXDYNAMIC_REDISTWO='n'
NGXDYNAMIC_SRCCACHE='n'
```

---

## Security Modules

```bash
NGINX_MODSECURITY='n'              # ModSecurity WAF
NGINX_TLS_FINGERPRINT='n'         # JA3 SSL fingerprinting
NGINX_SECURED='y'                  # Security-hardened compilation
NGINX_SSL_CACHE='n'                # SSL cert caching (nginx 1.27.4+)
```

---

## Performance Modules

```bash
NGINX_PAGESPEED='n'                # Google PageSpeed
NGINX_PASSENGER='n'                # Phusion Passenger
GPERFTOOLS_SOURCEINSTALL='n'       # Google Performance Tools
NGINX_MIMALLOC='n'                 # Microsoft mimalloc allocator
NGINX_NJS='n'                      # njs JavaScript module
```

---

## Compiler & Optimization Flags

### Compiler Selection
```bash
CLANG='n'                          # Use Clang/LLVM instead of GCC
CLANG_LTO_ENABLE='y'              # Link-Time Optimization
CLANG_LTO_FULL='n'                # Full LTO (vs Thin LTO)
```

### GCC Toolset Progression (EL7 → EL10)

**Verified from `centmin.sh:308-386` and Red Hat docs (2026-03-27)**:

| OS | System GCC | Centmin Mod Default | GCC Version | Condition |
|----|-----------|-------------------|-------------|-----------|
| EL7 | 4.8 | devtoolset-7 | GCC 7.2 | All |
| EL8 (<8.7) | 8.5 | gcc-toolset-11 | GCC 11.2 | `DEVTOOLSETELEVEN='y'` |
| EL8 (8.7-8.8) | 8.5 | gcc-toolset-12 | GCC 12.2 | `DEVTOOLSETTWELVE='y'` |
| EL8 (>=8.9) | 8.5 | gcc-toolset-13 | GCC 13.2 | `DEVTOOLSETTHIRTEEN='y'` |
| EL9 (9.0) | 11.x | System GCC 11 | GCC 11.x | No toolset |
| EL9 (9.1-9.2) | 11.x | gcc-toolset-12 | GCC 12.2 | `DEVTOOLSETTWELVE='y'` |
| EL9 (>=9.3) | 11.x | gcc-toolset-13 | GCC 13.2 | `DEVTOOLSETTHIRTEEN='y'` |
| EL10 (>=10.0) | **14.x** | gcc-toolset-14 | GCC 14.2 | `DEVTOOLSETFOURTEEN='y'` |

**Note**: `DEVTOOLSETFIFTTEEN` variable exists in Centmin Mod but is set to `'n'` across all platforms — gcc-toolset-15 not yet enabled.

**RPM Build Recommendation** (upgrading beyond Centmin Mod defaults):

| OS | Recommended Toolset | GCC Version | Rationale |
|----|-------------------|-------------|-----------|
| EL8 | gcc-toolset-14 | 14.2.1 | Latest available on EL8 AppStream |
| EL9 | gcc-toolset-15 | 15.1.1 | Available since RHEL 9.7 / AlmaLinux 9.7 |
| EL10 | System GCC 14 (or gcc-toolset-15) | 14.x (or 15.1.1) | System GCC already modern; toolset-15 optional |

**References**:
- [GCC and gcc-toolset versions in RHEL](https://developers.redhat.com/articles/2025/04/16/gcc-and-gcc-toolset-versions-rhel-explainer)
- [Red Hat GCC versions matrix](https://access.redhat.com/solutions/19458)
- [RHEL 10.1 Release Notes — GCC Toolset 15](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/en/documentation/Red_Hat_Enterprise_Linux/10/html/10.1_release_notes/overview)
- [AlmaLinux 8 gcc-toolset-14 advisory](https://errata.almalinux.org/8/ALSA-2025-1338.html)
- [gcc-toolset-15-gcc 15.1.1 RPM for EL9](https://rpmfind.net/linux/RPM/centos-stream/9/appstream/x86_64/gcc-toolset-15-gcc-15.1.1-2.5.el9.x86_64.html)

### Optimization Flags
```bash
GCC_OPTLEVEL='-O3'                # Optimization level
NGINX_FATLTO_OBJECTS='n'           # -ffat-lto-objects
FLTO_COMP='n'                     # Full LTO compilation
MARCH_TARGETNATIVE='n'            # CPU-specific -march=native
```

### Security Hardening (CFLAGS)
```
-O3                                # Optimization
-g3                                # Debug symbols
-fPIE                              # Position-independent executable
-fstack-protector-strong           # Stack canaries
-Wformat -Wformat-security         # Format string checks
-Wp,-D_FORTIFY_SOURCE=2            # Buffer overflow detection
--param=ssp-buffer-size=4          # Stack buffer size
-Bsymbolic-functions               # Symbol binding
-Wl,--as-needed                    # Link only needed libs
-Wl,-z,relro,-z,now                # RELRO + immediate binding
```

### Linker Selection
```bash
NGX_LDGOLD='n'                     # GNU gold linker
NGX_LDMOLD='n'                     # LLVM mold linker (5-15x faster)
```

---

## PCRE Regex Support

```bash
NGINX_PCRE='y'                     # PCRE support
NGINX_PCREJIT='y'                  # JIT compilation
NGINX_PCREVER='8.45'               # PCRE version
NGINX_PCRE_DYNAMIC='y'             # Dynamic library

NGINX_PCRE_TWO='n'                 # PCRE2 (nginx 1.21.5+)
NGINX_PCRETWOVER='10.39'
```

**Conflicts**: PCRE2 incompatible with ModSecurity and OpenResty Lua

---

## TLS/Protocol Settings

```bash
SSL_PROTOCOL_MODERN='y'            # Minimum TLSv1.2
OPENSSL_TLSONETHREE='y'            # TLSv1.3 support
NGINX_KTLS='n'                     # Kernel TLS (Linux 5.2+, OpenSSL 3.0+)
NGINX_PRIORITIZECHACHA='n'         # ChaCha20 priority
```

---

## Platform-Specific Handling

| Feature | EL7 | EL8 | EL9 | EL10 |
|---------|-----|-----|-----|------|
| Pkg Manager | yum | yum/dnf | dnf | dnf |
| Repository | base | PowerTools | CRB | CRB |
| GCC Toolset | devtoolset-7 | gcc-toolset-12 | gcc-toolset-13 | gcc-toolset-14 |
| OpenSSL | 1.0.2k | 1.1.1k | 3.0.x | 3.x |
| Systemd | Yes | Yes | Yes | Yes |
| Init Scripts | Supported | No | No | No |

**Version Detection Variables**:
- `CENTOS_SEVEN`, `CENTOS_EIGHT`, `CENTOS_NINE`, `CENTOS_TEN`
- `CENTOSVER` — numeric version

---

## Third-Party Modules (46+)

1. Headers-More-Nginx-Module (v0.38)
2. ngx-fancyindex (v0.5.2)
3. ngx_cache_purge (v2.5.3)
4. nginx-accesskey (v2.0.3)
5. nginx-http-concat
6. nginx-http-rdns
7. nginx-length-hiding-filter
8. testcookie-nginx-module
9. nginx-sticky-module-ng
10. nginx_upstream_check_module
11. nginx-rtmp-module
12. lua-nginx-module (v0.10.28)
13. stream-lua-nginx-module (v0.0.16)
14. lua-upstream-nginx-module (v0.07)
15. set-misc-nginx-module (v0.33)
16. echo-nginx-module (v0.63)
17. memc-nginx-module (v0.20)
18. srcache-nginx-module (v0.33)
19. redis2-nginx-module (v0.15)
20. ngx_brotli
21. zstd-nginx-module
22. ngx_http_geoip2_module
23. ngx_devel_kit (v0.3.2)
24. ModSecurity-nginx
25. ngx_ssl_fingerprint (JA3)
26. ngx_pagespeed
27. nginx-dav-ext-module
28. njs (v0.9.0)
29. And 19+ Lua-Resty library modules...

---

## Build Process Summary

```bash
cd /svr-setup/nginx-${NGINX_VERSION}

./configure \
  --with-ld-opt="..." \
  --with-cc-opt="..." \
  --prefix=/usr/local/nginx \
  --sbin-path=/usr/local/sbin/nginx \
  --conf-path=/usr/local/nginx/conf/nginx.conf \
  --build=${SETBUILD_VALUE} \                    # CPU-specific identifier
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-openssl=../openssl-${OPENSSL_VERSION} \  # or boringssl/awslc/libressl
  [... all module flags ...] \

make -j${MAKETHREADS}
make install
```

**Post-build**: binary stripping, systemd config, dynamic module loading config, configuration initialization.

---

## Key Differences from pkg-oss (Summary)

| Aspect | Centmin Mod | pkg-oss |
|--------|-------------|---------|
| Crypto Libraries | 4 (OpenSSL, BoringSSL, AWS-LC, LibreSSL) | System OpenSSL only |
| Install Prefix | `/usr/local/nginx` | `/etc/nginx` |
| Binary Path | `/usr/local/sbin/nginx` | `/usr/sbin/nginx` |
| Modules Path | `/usr/local/nginx/modules/` | `/usr/lib/nginx/modules/` |
| Compression | Cloudflare zlib, zlib-ng, brotli, zstd | System zlib, brotli module |
| Third-Party Modules | 46+ | 19 |
| Compiler Toolsets | devtoolset/gcc-toolset per EL version | System GCC |
| PCRE | PCRE or PCRE2 (configurable) | PCRE2 only |
| HTTP/3 | Via custom OpenSSL QUIC fork | Via system OpenSSL 3.x |
| Build Method | Source compile (make) | rpmbuild (spec files) |
| Config Variables | 575+ controllable variables | Fixed spec template |
| Extra Modules | fancyindex, cache_purge, modsecurity, pagespeed | Not included |
| LTO/PGO | Configurable LTO, planned PGO | None |
| CPU Tuning | -march=native option, CPU-specific build IDs | Generic builds |
