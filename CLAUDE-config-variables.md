# Configuration Variables Reference

## pkg-oss Build System Variables

### Root Makefile (`/Makefile`)

| Variable | Default | Description |
|----------|---------|-------------|
| `BRANCH` | (auto-detected) | Git branch name |
| `FLAVOR` | mainline or stable | Determined from branch name |
| `VERSION` | (from nginx.h) | Nginx version (e.g., 1.29.7) |
| `RELEASE` | 1 | RPM release number |
| `VERSION_NJS` | (from njs/version) | NJS module version |

### RPM Makefile (`rpm/SPECS/Makefile`)

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_TARGET` | oss | Build target: `oss` or `plus` |
| `BASE_VERSION` | `$(NGINX_VERSION)` | From `contrib/src/nginx/version` |
| `BASE_RELEASE` | 1 | RPM release number |
| `SRCPATH` | ../SOURCES | Path to RPM source files |
| `BUILD_ENV_PATH` | `${HOME}/rpmbuild` | rpmbuild working directory |
| `BASE_MODULES` | acme geoip image-filter njs otel perl xslt | Modules built with base |
| `MODULES` | (all discovered) | All available modules |

### Spec Template Variables (`nginx.spec.in`)

| Placeholder | Replaced With | Source |
|-------------|---------------|--------|
| `%%BASE_VERSION%%` | Nginx version | `contrib/src/nginx/version` |
| `%%BASE_RELEASE%%` | Release number | Makefile `BASE_RELEASE` |
| `%%PACKAGE_VENDOR%%` | Vendor string | Makefile |
| `%%BASE_CONFIGURE_ARGS%%` | All configure flags | Makefile `BASE_CONFIGURE_ARGS` |
| `%%BASE_PATCHES%%` | Patch definitions | Auto-generated from `contrib/src/` |

### Module Variables (`Makefile.module-*`)

Each module defines these (replace `<NAME>` with uppercase module name):

| Variable | Purpose | Example |
|----------|---------|---------|
| `MODULE_VERSION_<NAME>` | Module version | `1.0.0` |
| `MODULE_SOURCES_<NAME>` | Source tarballs | `mod-1.0.0.tar.gz` |
| `MODULE_PATCHES_<NAME>` | Patches to apply | `mod/fix.patch` |
| `MODULE_CONFARGS_<NAME>` | Configure flags | `--add-dynamic-module=mod-1.0.0` |
| `MODULE_DEFINITIONS_<NAME>` | RPM deps | `BuildRequires: lib-devel` |
| `MODULE_ENV_<NAME>` | Environment vars | `LUAJIT_INC=/path` |
| `MODULE_PREBUILD_<NAME>` | Pre-build commands | `make -C dep/` |
| `MODULE_PREINSTALL_<NAME>` | Pre-install commands | `rm duplicate.so` |
| `MODULE_FILES_<NAME>` | RPM file list | `%{_libdir}/nginx/modules/*.so` |
| `MODULE_POST_<NAME>` | Post-install message | Usage instructions |

### RPM Macros (OS Detection)

| Macro | Values | Purpose |
|-------|--------|---------|
| `%{?rhel}` | 7, 8, 9, 10 | RHEL/CentOS/AlmaLinux version |
| `%{?amzn}` | 2, 2023 | Amazon Linux version |
| `%{?suse_version}` | 1315, 1500, 1600 | SUSE version |
| `%{?fedora}` | (present/absent) | Fedora detection |
| `%{?dist}` | .el7, .el8, .el9, .el10 | Distribution tag |

## Compiler/Linker Flags

### Current pkg-oss Defaults

```makefile
WITH_CC_OPT = $(echo %{optflags} $(pcre2-config --cflags)) -fPIC
WITH_LD_OPT = -Wl,-z,relro -Wl,-z,now -pie
```

### Centmin Mod Compiler Flags (Target)

```bash
# CFLAGS (--with-cc-opt) — EL8/EL9:
-O3 -g3 -fPIE -fstack-protector-strong -fstack-clash-protection
-Wformat -Wformat-security -Wp,-D_FORTIFY_SOURCE=2
--param=ssp-buffer-size=4 -Bsymbolic-functions
-Wl,--as-needed -Wl,-z,relro,-z,now

# CFLAGS (--with-cc-opt) — EL10 (RHEL 10 uses FORTIFY_SOURCE=3):
-O3 -g3 -fPIE -fstack-protector-strong -fstack-clash-protection
-Wformat -Wformat-security -Wp,-D_FORTIFY_SOURCE=3
--param=ssp-buffer-size=4 -Bsymbolic-functions
-Wl,--as-needed -Wl,-z,relro,-z,now

# LDFLAGS (--with-ld-opt)
-L/opt/openssl/lib -I/opt/openssl/include
-lssl -lcrypto -Wl,-rpath,/opt/openssl/lib
```

### GCC Toolset Version Mapping (Verified 2026-03-27)

| OS | System GCC | Recommended Toolset | GCC Version | Enable Path |
|----|-----------|-------------------|-------------|-------------|
| EL8 | 8.5 | gcc-toolset-14 | 14.2.1 | `/opt/rh/gcc-toolset-14/enable` |
| EL9 | 11.x | gcc-toolset-15 | 15.1.1 | `/opt/rh/gcc-toolset-15/enable` |
| EL10 | 14.x | System GCC (no toolset needed) | 14.x | N/A |

**Activation methods**:
```bash
# In RPM spec %build section (recommended):
. /opt/rh/gcc-toolset-N/enable

# For interactive use:
scl enable gcc-toolset-N bash

# For single command:
scl enable gcc-toolset-N 'gcc -v'
```

**References**: [GCC and gcc-toolset in RHEL](https://developers.redhat.com/articles/2025/04/16/gcc-and-gcc-toolset-versions-rhel-explainer) | [RHEL 10 Hardening](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/en/documentation/Red_Hat_Enterprise_Linux/10/html/developing_c_and_cpp_applications_in_rhel_10/creating-c-or-cpp-applications)

## Configure Flags Comparison

### Present in Both (pkg-oss and Centmin Mod)

```
--with-compat
--with-file-aio
--with-threads
--with-http_ssl_module
--with-http_v2_module
--with-http_realip_module
--with-http_addition_module
--with-http_sub_module
--with-http_gzip_static_module
--with-http_stub_status_module
--with-http_secure_link_module
--with-http_slice_module (disabled by default in Centmin Mod)
--with-stream
--with-stream_ssl_module
--with-stream_ssl_preread_module
--with-stream_realip_module
```

### pkg-oss Only (not in default Centmin Mod)

```
--with-http_auth_request_module  (Centmin Mod: NGINX_AUTHREQ='n')
--with-http_dav_module           (Centmin Mod: NGINX_WEBDAV='n')
--with-http_flv_module           (Centmin Mod: NGINX_FLV='n')
--with-http_gunzip_module        (Centmin Mod: not separately toggled)
--with-http_mp4_module           (Centmin Mod: NGINX_MP4='n')
--with-http_random_index_module  (Centmin Mod: not included)
--with-mail                      (Centmin Mod: not included by default)
--with-mail_ssl_module           (Centmin Mod: not included by default)
```

### Centmin Mod Only (not in upstream pkg-oss)

```
--with-http_image_filter_module  (pkg-oss: separate module RPM)
--with-http_geoip_module         (pkg-oss: separate module RPM)
--add-module=../ngx-fancyindex   (not in pkg-oss)
--add-module=../ngx_cache_purge  (not in pkg-oss)
--with-openssl=../openssl-*      (pkg-oss: uses system OpenSSL)
--with-zlib=../cloudflare-zlib   (pkg-oss: uses system zlib)
--with-pcre=../pcre-*            (pkg-oss: uses system pcre2)
```
