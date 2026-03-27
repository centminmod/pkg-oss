# Active Context

## Current Session (2026-03-27)

### Project State

* Forked nginx/pkg-oss to centminmod/pkg-oss (branch: `centminmod`)
* Repository cloned to `/Volumes/AMZ3/AI-vibe-coding/pkg-oss/`
* **Phase 1 COMPLETE** — Foundation paths, package identity, minimal working RPM infrastructure
* Nginx version: 1.29.7, NJS version: 0.9.6

### Completed Work

1. **Analyzed upstream nginx pkg-oss RPM build system** → documented in CLAUDE-nginx-pkg-oss-defaults-info.md
   * Spec templates, configure flags, 19 dynamic modules
   * Per-OS handling (RHEL 7-10, Amazon Linux, SUSE, Fedora)
   * Build dependencies, patch system, package types

2. **Analyzed Centmin Mod nginx compilation** → documented in CLAUDE-centminmod-nginx-info.md
   * 575+ configurable variables across 53 categories
   * 4 crypto libraries (OpenSSL, BoringSSL, AWS-LC, LibreSSL)
   * 46+ third-party modules, dynamic module system
   * Compiler toolset progression (EL7→EL10)
   * Key differences table vs pkg-oss

3. **Documented CI/CD strategy** → documented in CLAUDE-nginx-rpm-ci-workflows.md
   * Explored 193 existing Centmin Mod GitHub Actions workflows as templates
   * Docker-based testing (AlmaLinux 8/9/10 with Sysbox runtime)
   * RPM build + integration test workflow patterns
   * 5 architectural decisions documented

4. **Set up memory bank system** — all CLAUDE-*.md context files populated

5. **Verified with context7 docs**: Nginx building from source (configure flags, dynamic modules, custom OpenSSL paths), GitHub Actions (matrix strategy, container jobs, artifact upload, Docker-based CI)

### Key References

* Centmin Mod codebase: `/Users/george/D7378/PC/gitrepos/www_git/centminmod-claudecode` (READ-ONLY)
* CI workflow templates: `/Users/george/D7378/PC/gitrepos/www_git/centminmod-workflows/`
* Primary build file to modify: `rpm/SPECS/Makefile` + `rpm/SPECS/nginx.spec.in`
* Primary reference: `inc/nginx_configure.inc` (6,774 lines in Centmin Mod)

---

## Implementation Plan — Centmin Mod Nginx RPM Packages

### Project Goal

Transform the forked nginx/pkg-oss RPM build system to produce **Centmin Mod-flavored Nginx RPM packages** for AlmaLinux 8, 9, 10 — matching Centmin Mod's nginx configuration, module set, crypto library choices, compiler optimizations, and installation paths.

### Strategic Approach: Incremental Layering

Rather than rewriting the entire build system at once, we layer Centmin Mod customizations on top of the proven upstream pkg-oss infrastructure in **6 phases**, each producing testable RPMs. Each phase builds on the previous one and can be validated independently via CI.

**Why incremental**: A single massive change would be nearly impossible to debug when rpmbuild fails. By producing working RPMs at each phase, we can isolate regressions to the specific change set that caused them.

---

## Phase 1: Foundation — Paths, Package Identity & Minimal Working RPM

**Goal**: Produce an RPM that installs to Centmin Mod paths with Centmin Mod package identity, using system OpenSSL and the same configure flags as upstream.

**Rationale**: This validates the fundamental spec file modifications work before adding complexity. If the RPM installs cleanly with Centmin Mod paths on AlmaLinux 9, everything else is just adding features on top.

### Phase 1 Tasks

#### 1.1 — Modify `rpm/SPECS/Makefile` Package Identity

Change `PACKAGE_VENDOR` and add Centmin Mod branding:
```makefile
PACKAGE_VENDOR = Centmin Mod <centminmod@centminmod.com>
```

Add a new variable to distinguish Centmin Mod RPMs:
```makefile
PACKAGE_NAME_PREFIX = centminmod-nginx
# or keep nginx but use a different release suffix
```

**Decision needed**: Package naming strategy:
- **Option A**: `centminmod-nginx-1.29.7-1.el9.x86_64.rpm` — clearly distinct, no conflict with official nginx RPMs
- **Option B**: `nginx-1.29.7-1.cm.el9.x86_64.rpm` — same base name, different release tag
- **Recommendation**: Option A — avoids any `yum`/`dnf` confusion with upstream nginx packages and allows side-by-side installation

#### 1.2 — Modify `rpm/SPECS/nginx.spec.in` Installation Paths

Change the core path definitions to match Centmin Mod:
```spec
%define nginx_home /usr/local/nginx
%define nginx_user nginx
%define nginx_group nginx
%define nginx_loggroup adm
```

Change `BASE_CONFIGURE_ARGS` paths in `rpm/SPECS/Makefile`:
```
# FROM (pkg-oss):
--prefix=%{_sysconfdir}/nginx            → --prefix=/usr/local/nginx
--sbin-path=%{_sbindir}/nginx            → --sbin-path=/usr/local/sbin/nginx
--modules-path=%{_libdir}/nginx/modules  → --modules-path=/usr/local/nginx/modules
--conf-path=%{_sysconfdir}/nginx/nginx.conf → --conf-path=/usr/local/nginx/conf/nginx.conf
--error-log-path=...                     → --error-log-path=/usr/local/nginx/logs/error.log
--http-log-path=...                      → --http-log-path=/usr/local/nginx/logs/access.log
--pid-path=...                           → --pid-path=/var/run/nginx.pid
--lock-path=...                          → --lock-path=/var/run/nginx.lock
```

Also update temp paths, cache paths, and the `%files` section to match.

#### 1.3 — Update `rpm/SOURCES/nginx.conf` for Centmin Mod Defaults

Modify the default nginx.conf to match Centmin Mod conventions:
- Worker processes: auto
- Include `/usr/local/nginx/conf/conf.d/*.conf`
- Include `/usr/local/nginx/conf/dynamic-modules.conf`
- Centmin Mod-specific performance tuning defaults

#### 1.4 — Update `rpm/SOURCES/nginx.service` for New Paths

Modify systemd service file:
```ini
ExecStart=/usr/local/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
PIDFile=/var/run/nginx.pid
```

#### 1.5 — Update `%files` Section in `nginx.spec.in`

Rewrite the `%files` section for Centmin Mod paths:
```spec
/usr/local/sbin/nginx
/usr/local/sbin/nginx-debug
%dir /usr/local/nginx
%dir /usr/local/nginx/conf
%dir /usr/local/nginx/conf/conf.d
%dir /usr/local/nginx/modules
%dir /usr/local/nginx/logs
%config(noreplace) /usr/local/nginx/conf/nginx.conf
...
```

#### 1.6 — Drop EL7, SUSE, Fedora, Amazon Linux Conditionals

Since Centmin Mod targets EL8/9/10 only, simplify the spec:
- Remove RHEL 7 epoch/openssl handling
- Remove SUSE blocks entirely
- Remove Fedora blocks
- Remove Amazon Linux special cases
- Keep RHEL 8, 9, 10 blocks

**Alternatively**: Keep them but make them no-ops (safer for upstream merges).

**Recommendation**: Comment them out with clear markers rather than delete, to ease upstream merges.

#### 1.7 — Create CI Workflow: `build-nginx-rpm.yml`

First GitHub Actions workflow to validate the RPM builds:

```yaml
name: Build Centmin Mod Nginx RPM
on:
  workflow_dispatch:
    inputs:
      el_versions:
        type: choice
        options: [el10, el9, el8, el9-el10, el8-el9-el10]
        default: el9
  push:
    branches: [centminmod]
    paths:
      - 'rpm/**'
      - 'contrib/**'

jobs:
  build:
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        el_version: [8, 9, 10]
    steps:
      - uses: actions/checkout@v4
      - name: Build rpmbuild Docker image
        run: docker build -f docker/Dockerfile.rpmbuild-el${{ matrix.el_version }} -t rpmbuild:el${{ matrix.el_version }} .
      - name: Run rpmbuild
        run: |
          mkdir -p output
          docker run --rm -v ${{ github.workspace }}/output:/output rpmbuild:el${{ matrix.el_version }}
      - name: Upload RPM artifacts
        uses: actions/upload-artifact@v4
        with:
          name: nginx-rpms-el${{ matrix.el_version }}
          path: output/*.rpm
```

#### 1.8 — Create Dockerfiles for rpmbuild Environments

Create `docker/Dockerfile.rpmbuild-el{8,9,10}`:

```dockerfile
FROM almalinux:9
RUN dnf -y groupinstall 'Development Tools' && \
    dnf -y install zlib-devel pcre2-devel openssl-devel systemd-devel \
    wget tar gzip rpm-build rpmdevtools && \
    dnf clean all
RUN useradd -m builder && \
    mkdir -p /home/builder/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
COPY rpm/SPECS/ /home/builder/rpmbuild/SPECS/
COPY rpm/SOURCES/ /home/builder/rpmbuild/SOURCES/
COPY contrib/ /home/builder/contrib/
USER builder
WORKDIR /home/builder/rpmbuild
CMD ["bash", "-c", "cd SPECS && make nginx.spec && rpmbuild --define '_topdir /home/builder/rpmbuild' -ba SPECS/nginx.spec && cp RPMS/*/* /output/"]
```

### Phase 1 Validation Criteria

- [ ] `rpmbuild -ba nginx.spec` succeeds on AlmaLinux 8, 9, 10
- [ ] RPM installs cleanly: `dnf localinstall centminmod-nginx-*.rpm`
- [ ] Binary at `/usr/local/sbin/nginx`
- [ ] Config at `/usr/local/nginx/conf/nginx.conf`
- [ ] `nginx -V` shows Centmin Mod paths
- [ ] `systemctl start nginx` works
- [ ] `curl http://localhost/` returns default page
- [ ] `nginx -t` config test passes

---

## Phase 2: Configure Flags — Match Centmin Mod Module Set

**Goal**: Align the `BASE_CONFIGURE_ARGS` with Centmin Mod's static module set and add the Centmin Mod-specific modules that pkg-oss builds as separate packages.

**Rationale**: With paths working, we now match the feature set. This phase focuses on flags that use system libraries only — no custom crypto yet.

### Phase 2 Tasks

#### 2.1 — Update Static Configure Flags

Add flags that Centmin Mod enables by default but pkg-oss doesn't:
```
--with-http_image_filter_module    (Centmin Mod: built-in, pkg-oss: separate RPM)
--with-http_geoip_module           (or switch to geoip2 only)
```

Remove flags Centmin Mod doesn't use by default:
```
# Keep but make optional:
--with-http_auth_request_module    (CM default: off, but useful)
--with-http_dav_module             (CM default: off)
--with-http_flv_module             (CM default: off)
--with-http_mp4_module             (CM default: off)
--with-http_random_index_module    (CM: not included)
--with-mail                        (CM: not included by default)
--with-mail_ssl_module             (CM: not included by default)
```

**Decision needed**: Whether to keep the upstream module set (more features) or match Centmin Mod exactly (leaner binary).

**Recommendation**: Keep the upstream module set as a baseline (they're zero-cost if unused), then add Centmin Mod extras on top. Matches both upstream compatibility and Centmin Mod feature expectations.

#### 2.2 — Add Centmin Mod-Specific Static Modules

These modules Centmin Mod builds statically that pkg-oss doesn't include:

```makefile
# Add to BASE_CONFIGURE_ARGS:
--add-module=../ngx-fancyindex-$(FANCYINDEX_VERSION)
--add-module=../ngx_cache_purge-$(CACHEPURGE_VERSION)
```

This requires adding source tarballs to `contrib/src/`:
- `contrib/src/ngx-fancyindex/`
- `contrib/src/ngx_cache_purge/`

#### 2.3 — Create New Module Makefiles for Centmin Mod Modules

Create `Makefile.module-*` files for modules not in upstream:

**Priority modules** (Centmin Mod default enabled):
- `Makefile.module-fancyindex` — fancy directory listing
- `Makefile.module-cache-purge` — cache purging
- `Makefile.module-echo` — echo module (debugging/testing)
- `Makefile.module-memc` — memcache module
- `Makefile.module-redis2` — Redis module
- `Makefile.module-srcache` — subrequest-based caching
- `Makefile.module-lua-upstream` — Lua upstream module
- `Makefile.module-stream-lua` — stream Lua module
- `Makefile.module-zstd` — Zstandard compression

**Optional modules** (Centmin Mod available but off by default):
- `Makefile.module-modsecurity` — ModSecurity WAF
- `Makefile.module-pagespeed` — Google PageSpeed
- `Makefile.module-testcookie` — bot detection
- `Makefile.module-dav-ext` — WebDAV extensions
- `Makefile.module-upstream-check` — upstream health checks

#### 2.4 — Update `BASE_MODULES` in Makefile

```makefile
# Upstream:
BASE_MODULES = acme geoip image-filter njs otel perl xslt

# Centmin Mod:
BASE_MODULES = brotli geoip2 headers-more image-filter lua ndk njs set-misc xslt
# (acme, otel, perl remain as optional module RPMs)
```

#### 2.5 — Add Compiler Optimization Flags

Update `WITH_CC_OPT` and `WITH_LD_OPT` in nginx.spec.in:

```spec
# Current pkg-oss:
%define WITH_CC_OPT $(echo %{optflags} $(pcre2-config --cflags)) -fPIC
%define WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -pie

# Centmin Mod enhanced (EL8/EL9):
%define WITH_CC_OPT -O3 -g3 -fPIE -fstack-protector-strong -fstack-clash-protection -Wformat -Wformat-security -Wp,-D_FORTIFY_SOURCE=2 --param=ssp-buffer-size=4 $(pcre2-config --cflags) -fPIC
%define WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -pie -Wl,--as-needed -Wl,-Bsymbolic-functions

# EL10 uses -D_FORTIFY_SOURCE=3 (Red Hat recommended for RHEL 10):
# %define WITH_CC_OPT -O3 -g3 -fPIE -fstack-protector-strong -fstack-clash-protection -Wformat -Wformat-security -Wp,-D_FORTIFY_SOURCE=3 $(pcre2-config --cflags) -fPIC
```

**Note**: RHEL 10 recommends `-D_FORTIFY_SOURCE=3` (stronger than level 2) and adds `-fstack-clash-protection`. See [RHEL 10 Hardening Guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/en/documentation/Red_Hat_Enterprise_Linux/10/html/developing_c_and_cpp_applications_in_rhel_10/creating-c-or-cpp-applications).

#### 2.6 — Add GCC Toolset Support (Verified 2026-03-27)

**GCC Toolset Availability Matrix** (verified via Red Hat docs + AlmaLinux repos):

| OS | System GCC | Recommended Toolset | GCC Version | Enable Path |
|----|-----------|-------------------|-------------|-------------|
| EL8 | 8.5 | gcc-toolset-14 | 14.2.1 | `/opt/rh/gcc-toolset-14/enable` |
| EL9 | 11.x | gcc-toolset-15 | 15.1.1 | `/opt/rh/gcc-toolset-15/enable` |
| EL10 | **14.x** | System GCC (or gcc-toolset-15) | 14.x (or 15.1.1) | N/A (or `/opt/rh/gcc-toolset-15/enable`) |

**Key insight**: EL10's system GCC is already 14.x — gcc-toolset is optional, not required.

**Centmin Mod's current defaults** (from `centmin.sh:308-386`):
- EL8 >= 8.9: gcc-toolset-13 (we upgrade to 14)
- EL9 >= 9.3: gcc-toolset-13 (we upgrade to 15)
- EL10: gcc-toolset-14 (we use system GCC 14 or upgrade to 15)
- `DEVTOOLSETFIFTTEEN='n'` across all platforms — not yet enabled in Centmin Mod

Add per-EL compiler toolset activation in the spec:
```spec
%if 0%{?rhel} == 8
BuildRequires: gcc-toolset-14-gcc gcc-toolset-14-gcc-c++
%endif
%if 0%{?rhel} == 9
BuildRequires: gcc-toolset-15-gcc gcc-toolset-15-gcc-c++
%endif
# EL10: system GCC 14.x is sufficient — no toolset BuildRequires needed
# Optionally add gcc-toolset-15 for GCC 15 on EL10:
# %if 0%{?rhel} == 10
# BuildRequires: gcc-toolset-15-gcc gcc-toolset-15-gcc-c++
# %endif
```

Then in `%build` (source enable script before ./configure):
```spec
%build
%if 0%{?rhel} == 8
. /opt/rh/gcc-toolset-14/enable
%endif
%if 0%{?rhel} == 9
. /opt/rh/gcc-toolset-15/enable
%endif
# EL10: system GCC 14 used by default — no enable needed
./configure %{BASE_CONFIGURE_ARGS} ...
```

**Note**: `%{optflags}` still reflects system defaults after sourcing — explicitly append `-O3` and other optimization flags to `WITH_CC_OPT`.

**References**:
- [GCC and gcc-toolset versions in RHEL](https://developers.redhat.com/articles/2025/04/16/gcc-and-gcc-toolset-versions-rhel-explainer)
- [RHEL 10.1 Release Notes — GCC Toolset 15](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/en/documentation/Red_Hat_Enterprise_Linux/10/html/10.1_release_notes/overview)
- [RHEL 9.7 Release Notes](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html-single/9.7_release_notes/index)

### Phase 2 Validation Criteria

- [ ] `nginx -V` shows fancyindex, cache_purge in compiled modules
- [ ] `nginx -V` shows enhanced compiler flags (-O3, -fstack-protector-strong, etc.)
- [ ] GCC toolset version matches expected per EL version
- [ ] All dynamic modules (.so files) load correctly
- [ ] Module RPMs install and load independently
- [ ] No missing symbols or library errors

---

## Phase 3: Custom Crypto Libraries — OpenSSL, BoringSSL, AWS-LC

**Goal**: Add build-time selectable crypto library support. This is the most complex phase as it requires compiling crypto libraries from source as part of the RPM build process.

**Rationale**: This is the core differentiator of Centmin Mod. The RPM must be able to bundle custom crypto libraries, especially for HTTP/3 QUIC support with the correct OpenSSL fork.

### Crypto Library Strategy

**Decision**: Use `rpmbuild --define 'crypto <library>'` to select crypto library at build time.

```bash
# Build with system OpenSSL (default, simplest):
rpmbuild -ba nginx.spec

# Build with custom OpenSSL (QUIC-patched):
rpmbuild -ba nginx.spec --define 'crypto openssl-quic'

# Build with AWS-LC:
rpmbuild -ba nginx.spec --define 'crypto awslc'

# Build with BoringSSL:
rpmbuild -ba nginx.spec --define 'crypto boringssl'
```

### Phase 3 Tasks

#### 3.1 — Add Crypto Library Selection to `nginx.spec.in`

```spec
# Crypto library selection (default: system)
%if "%{?crypto}" == "openssl-quic"
%define crypto_name OpenSSL QUIC
%define crypto_version 1.1.1w+quic
%define with_custom_crypto 1
%define openssl_source openssl-%{crypto_version}.tar.gz
%define openssl_configure_arg --with-openssl=../openssl-%{crypto_version}
%define openssl_opt enable-ec_nistp_64_gcc_128 enable-tls1_3
%endif

%if "%{?crypto}" == "awslc"
%define crypto_name AWS-LC
%define crypto_version 1.60.0
%define with_custom_crypto 1
# AWS-LC uses cmake, needs special handling
%endif

%if "%{?crypto}" == "boringssl"
%define crypto_name BoringSSL
%define with_custom_crypto 1
# BoringSSL uses cmake + go, needs special handling
%endif

# Default: system OpenSSL
%if !0%{?with_custom_crypto}
%define crypto_name System OpenSSL
%define openssl_configure_arg %{nil}
%endif
```

#### 3.2 — Add Crypto Source Tarballs to contrib/

Create download and checksum infrastructure for:
- `contrib/src/openssl-quic/` — OpenSSL 1.1.1w+quic fork
- `contrib/src/awslc/` — AWS-LC v1.60.0
- `contrib/src/boringssl/` — BoringSSL latest

#### 3.3 — Implement OpenSSL QUIC Build in Spec

The simplest approach — `--with-openssl=../openssl-*` is a nginx configure flag that builds OpenSSL from source as part of the nginx build:

```spec
%if 0%{?with_custom_crypto} && "%{?crypto}" == "openssl-quic"
Source100: openssl-%{crypto_version}.tar.gz
%endif

%build
%if 0%{?with_custom_crypto} && "%{?crypto}" == "openssl-quic"
tar xzf %{SOURCE100}
OPENSSL_OPT="--with-openssl=../openssl-%{crypto_version} --with-openssl-opt='%{openssl_opt}'"
%endif

./configure %{BASE_CONFIGURE_ARGS} $OPENSSL_OPT \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}"
```

#### 3.4 — Implement AWS-LC Build in Spec

AWS-LC requires a cmake pre-build step:
```spec
%if "%{?crypto}" == "awslc"
BuildRequires: cmake golang
# Pre-build AWS-LC
cd aws-lc-%{crypto_version}
cmake -B build -DCMAKE_INSTALL_PREFIX=%{_builddir}/awslc-install ...
cmake --build build --target install
# Point nginx to it
OPENSSL_OPT="--with-cc-opt='-I%{_builddir}/awslc-install/include' --with-ld-opt='-L%{_builddir}/awslc-install/lib -lssl -lcrypto'"
%endif
```

#### 3.5 — Implement BoringSSL Build in Spec

Similar cmake approach:
```spec
%if "%{?crypto}" == "boringssl"
BuildRequires: cmake golang
# Pre-build BoringSSL
cd boringssl
cmake -B build ...
cmake --build build
# Use BoringSSL's include/lib paths
%endif
```

#### 3.6 — Add HTTP/3 Conditional to Crypto Selection

HTTP/3 availability depends on crypto library:
```spec
%if "%{?crypto}" == "openssl-quic" || "%{?crypto}" == "boringssl"
%define with_http3 1
%endif

# System OpenSSL on EL9/10 (3.x) also supports QUIC natively
%if !0%{?with_custom_crypto} && 0%{?rhel} >= 9
%define with_http3 1
%endif
```

#### 3.7 — Update CI Workflow Matrix for Crypto Variants

```yaml
strategy:
  matrix:
    el_version: [8, 9, 10]
    crypto: [system, openssl-quic, awslc]
```

#### 3.8 — Package Naming per Crypto Variant

Each crypto variant produces differently-named RPMs to allow co-existence in repos:
```
centminmod-nginx-1.29.7-1.el9.x86_64.rpm              # system OpenSSL
centminmod-nginx-openssl-quic-1.29.7-1.el9.x86_64.rpm # QUIC OpenSSL
centminmod-nginx-awslc-1.29.7-1.el9.x86_64.rpm        # AWS-LC
centminmod-nginx-boringssl-1.29.7-1.el9.x86_64.rpm    # BoringSSL
```

### Phase 3 Validation Criteria

- [ ] System OpenSSL build still works (no regression)
- [ ] OpenSSL QUIC variant builds and `nginx -V` shows quic-patched OpenSSL
- [ ] AWS-LC variant builds, `nginx -V` shows AWS-LC
- [ ] BoringSSL variant builds if implemented
- [ ] HTTP/3 tests pass with QUIC-capable crypto libraries
- [ ] Libraries are bundled in RPM (not relying on external install)
- [ ] `ldd /usr/local/sbin/nginx` shows correct crypto library linkage

---

## Phase 4: Custom Compression Libraries — Zlib, Brotli, Zstd

**Goal**: Add custom zlib (Cloudflare zlib or zlib-ng) compilation and ensure Brotli and Zstandard modules work correctly.

**Rationale**: Centmin Mod's performance advantage partly comes from optimized compression. Cloudflare zlib provides better gzip performance. Brotli and Zstd provide modern compression alternatives.

### Phase 4 Tasks

#### 4.1 — Add Cloudflare Zlib Source to Build

```spec
# In BUILD section:
Source200: cloudflare-zlib-%{cf_zlib_version}.tar.gz

%build
tar xzf %{SOURCE200}
ZLIB_OPT="--with-zlib=../cloudflare-zlib-%{cf_zlib_version}"
./configure %{BASE_CONFIGURE_ARGS} $ZLIB_OPT ...
```

#### 4.2 — Add Zlib-ng Alternative

When zlib-ng is preferred:
```spec
%if "%{?zlib}" == "zlibng"
Source200: zlib-ng-%{zlibng_version}.tar.gz
%define zlib_configure_arg --with-zlib=../zlib-ng-%{zlibng_version}
%endif
```

#### 4.3 — Ensure Brotli Module Works

Brotli is already in upstream pkg-oss as `Makefile.module-brotli`. Verify it works with Centmin Mod paths. May need to update `MODULE_FILES_brotli` for `/usr/local/nginx/modules/`.

#### 4.4 — Add Zstandard Module

Create `Makefile.module-zstd`:
```makefile
MODULE_VERSION_zstd = 0.1.1
MODULE_SOURCES_zstd = zstd-nginx-module-$(MODULE_VERSION_zstd).tar.gz
MODULE_CONFARGS_zstd = --add-dynamic-module=zstd-nginx-module-$(MODULE_VERSION_zstd)
MODULE_DEFINITIONS_zstd = BuildRequires: libzstd-devel
MODULE_FILES_zstd = /usr/local/nginx/modules/ngx_http_zstd_filter_module.so \
    /usr/local/nginx/modules/ngx_http_zstd_static_module.so
```

#### 4.5 — Add Custom PCRE/PCRE2 Compilation Option

```spec
%if 0%{?with_custom_pcre}
Source201: pcre2-%{pcre2_version}.tar.gz
%define pcre_configure_arg --with-pcre=../pcre2-%{pcre2_version} --with-pcre-jit
%endif
```

### Phase 4 Validation Criteria

- [ ] Cloudflare zlib builds and links correctly
- [ ] gzip compression benchmarks show improvement over system zlib
- [ ] Brotli module loads and compresses correctly
- [ ] Zstandard module loads and compresses correctly
- [ ] PCRE2 with JIT works when compiled from source
- [ ] All compression modules work together without conflicts

---

## Phase 5: LTO, Advanced Compiler Optimizations & Build Variants

**Goal**: Add Link-Time Optimization, GCC PGO (profile-guided optimization), and advanced compiler flag support matching Centmin Mod's performance-tuned builds.

**Rationale**: Centmin Mod's performance edge comes from aggressive compiler optimization that upstream nginx packages don't use.

### Phase 5 Tasks

#### 5.1 — Add LTO Support

```spec
%if 0%{?with_lto}
%define lto_cc_opt -flto=auto -ffat-lto-objects
%define lto_ld_opt -flto=auto
%endif
```

**Consideration**: LTO requires significant memory (16+ GB RAM for full nginx build). CI runners need adequate resources.

#### 5.2 — Add -march=native / CPU-Specific Builds

```spec
%if 0%{?with_native}
%define march_opt -march=native -mtune=native
%endif
```

**Caveat**: `-march=native` makes RPMs non-portable. Only useful for builds targeting a specific server. Consider `-march=x86-64-v2` or `-march=x86-64-v3` for broader compatibility.

#### 5.3 — Add Mold/Gold Linker Support

```spec
%if 0%{?with_mold}
BuildRequires: mold
%define ld_opt -fuse-ld=mold
%endif
```

#### 5.4 — Add PGO Support (Future)

Profile-Guided Optimization requires a two-pass build:
1. Build with `-fprofile-generate`
2. Run representative workload to collect profile data
3. Rebuild with `-fprofile-use`

This is complex for RPM packaging and may be a stretch goal.

### Phase 5 Validation Criteria

- [ ] LTO builds succeed and produce smaller binaries
- [ ] Benchmarks show measurable improvement with LTO
- [ ] `-march=x86-64-v3` builds work on modern CPUs
- [ ] Mold linker reduces build time significantly
- [ ] All optimization combinations don't break module loading

---

## Phase 6: Integration Testing, Documentation & Release Pipeline

**Goal**: Create comprehensive CI/CD pipeline with integration testing, RPM repository creation, and release automation.

**Rationale**: Producing RPMs is only half the job — they need to be validated, signed, and distributed.

### Phase 6 Tasks

#### 6.1 — Create Integration Test Workflow

`test-nginx-rpm-install.yml`:
```yaml
jobs:
  test:
    runs-on: ubuntu-24.04
    strategy:
      matrix:
        el_version: [8, 9, 10]
    steps:
      - Install Sysbox runtime
      - Start AlmaLinux container with systemd (sysbox-runc)
      - Copy RPM artifacts into container
      - Run: dnf localinstall *.rpm
      - Validate: nginx -V (check configure flags)
      - Validate: nginx -t (config test)
      - Validate: systemctl start/stop/reload nginx
      - Validate: curl http://localhost/
      - Validate: Dynamic module loading
      - Validate: ldd shows correct libraries
      - Validate: rpm -qi shows correct package info
      - Upload validation logs
```

#### 6.2 — Create RPM Signing Workflow

```yaml
- name: Sign RPMs
  run: |
    rpm --import RPM-GPG-KEY-centminmod
    rpm --addsign output/*.rpm
```

#### 6.3 — Create RPM Repository (Cloudflare R2)

Push signed RPMs to Cloudflare R2 for distribution:
```yaml
- name: Create YUM repository
  run: createrepo_c output/
- name: Upload to R2
  uses: cloudflare/wrangler-action@v3
  with:
    command: r2 object put centminmod-rpms/el${{ matrix.el_version }}/...
```

#### 6.4 — Create Orchestration Workflow

`manual-trigger-all.yml`: Triggers build → test → sign → publish in sequence.

#### 6.5 — Create Release Automation

Auto-detect new nginx versions, run builds, test, and prepare releases.

#### 6.6 — Documentation

- README update for fork-specific instructions
- RPM installation guide for end users
- Module configuration guide

### Phase 6 Validation Criteria

- [ ] Integration tests pass on all EL versions
- [ ] RPMs are properly signed
- [ ] YUM repository is accessible and `dnf install` works from it
- [ ] Full pipeline runs: build → test → sign → publish
- [ ] Release automation detects new nginx versions correctly

---

## Cross-Cutting Concerns

### Upstream Merge Strategy

Keep the `centminmod` branch rebased or merge-compatible with upstream `master`:
- Centmin Mod changes go in clearly marked sections
- Use `%%CMM_*%%` template variables alongside `%%BASE_*%%`
- Keep upstream files that we don't modify untouched
- Regular `git merge origin/master` to pick up new nginx versions and module updates

### Module Path Convention

All Centmin Mod module Makefiles use:
```makefile
MODULE_FILES_<name> = /usr/local/nginx/modules/ngx_*.so
```
Instead of upstream's:
```makefile
MODULE_FILES_<name> = %{_libdir}/nginx/modules/ngx_*.so
```

### Debug Build Strategy

Keep upstream's dual-build pattern (debug + release) but install debug binary to `/usr/local/sbin/nginx-debug` instead of `/usr/sbin/nginx-debug`.

### Epoch Strategy for Centmin Mod

Use a new epoch scheme to prevent version confusion:
```spec
# Centmin Mod epochs (independent from upstream nginx):
# EL8: Epoch 10
# EL9: Epoch 10
# EL10: Epoch 10
```

---

## Implementation Priority & Dependencies

```
Phase 1 (Foundation) ← No dependencies, start here
    │
    ├── Phase 2 (Configure Flags) ← Depends on Phase 1 paths working
    │       │
    │       ├── Phase 3 (Crypto) ← Depends on Phase 2 flags infrastructure
    │       │       │
    │       │       └── Phase 4 (Compression) ← Can parallel with Phase 3
    │       │
    │       └── Phase 5 (LTO/Optimizations) ← Depends on Phase 2 compiler support
    │
    └── Phase 6 (Integration/Release) ← Depends on at least Phase 1-2 complete
```

**Minimum Viable Product (MVP)**: Phase 1 + Phase 2 = a working RPM with Centmin Mod paths, module set, and compiler flags using system OpenSSL. This is already a huge improvement over the current source-compile approach.

**Stretch Goals**: Phase 3 (crypto) is the high-value differentiator but also highest complexity. Phase 5 (LTO) is nice-to-have.

---

## Open Questions & Decisions Needed

### 1. Package Naming
- `centminmod-nginx` vs `nginx` with custom release tag?
- **Impact**: Determines whether RPM can coexist with official nginx

### 2. Should Centmin Mod-Specific Modules Be Static or Dynamic?
- Static (compiled into binary): Smaller deployment, no .so management
- Dynamic (.so files): More flexible, can update modules independently
- **Recommendation**: Dynamic for most modules (matches upstream pattern), static for universally-used ones (fancyindex, cache_purge)

### 3. Custom Config File Location
- `/usr/local/nginx/conf/` (Centmin Mod traditional)
- `/etc/centminmod-nginx/` (more FHS-compliant for RPMs)
- **Recommendation**: `/usr/local/nginx/conf/` for backward compatibility

### 4. Should We Build a Single "Fat" RPM or Many Small Ones?
- Fat: One RPM with everything (simpler install)
- Small: Base + module RPMs (more control, smaller base)
- **Recommendation**: Hybrid — base RPM includes commonly-used modules, optional ones as separate RPMs

### 5. How to Handle nginx.conf Upgrades?
- RPM `%config(noreplace)` prevents overwriting user configs
- But how to ship new defaults for new Centmin Mod features?
- **Recommendation**: Use `%config(noreplace)` for main nginx.conf, ship example configs alongside

---

## File Modification Summary

### Files to Create (New)

| File | Phase | Purpose |
|------|-------|---------|
| `docker/Dockerfile.rpmbuild-el8` | 1 | Docker build env for EL8 |
| `docker/Dockerfile.rpmbuild-el9` | 1 | Docker build env for EL9 |
| `docker/Dockerfile.rpmbuild-el10` | 1 | Docker build env for EL10 |
| `.github/workflows/build-nginx-rpm.yml` | 1 | CI: Build RPMs |
| `.github/workflows/test-nginx-rpm-install.yml` | 6 | CI: Integration tests |
| `rpm/SPECS/Makefile.module-fancyindex` | 2 | Fancyindex module build |
| `rpm/SPECS/Makefile.module-cache-purge` | 2 | Cache purge module build |
| `rpm/SPECS/Makefile.module-echo` | 2 | Echo module build |
| `rpm/SPECS/Makefile.module-zstd` | 4 | Zstandard module build |
| `rpm/SOURCES/nginx.centminmod.conf` | 1 | Centmin Mod default config |
| `rpm/SOURCES/centminmod-nginx.service` | 1 | Centmin Mod systemd service |

### Files to Modify (Existing)

| File | Phase | Changes |
|------|-------|---------|
| `rpm/SPECS/Makefile` | 1-3 | Paths, package name, vendor, configure args, crypto selection |
| `rpm/SPECS/nginx.spec.in` | 1-5 | Paths, deps, files section, crypto conditionals, compiler flags |
| `rpm/SOURCES/nginx.conf` | 1 | Update paths for `/usr/local/nginx/` |
| `rpm/SOURCES/nginx.service` | 1 | Update paths for Centmin Mod binary location |
| `.github/workflows/ci.yml` | 1 | Add Centmin Mod RPM build target |

### Files to Reference (Read-Only)

| File | Purpose |
|------|---------|
| `/Users/george/D7378/PC/gitrepos/www_git/centminmod-claudecode/inc/nginx_configure.inc` | Exact configure flags |
| `/Users/george/D7378/PC/gitrepos/www_git/centminmod-claudecode/example/custom_config.inc` | All 575 variables |
| `/Users/george/D7378/PC/gitrepos/www_git/centminmod-workflows/.github/workflows/*.yml` | CI patterns |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| rpmbuild fails with custom paths | High | Phase 1 validates early; incremental changes |
| Custom crypto adds >20 min to build time | Medium | Cached Docker layers; parallel builds |
| Module ABI incompatibility with custom OpenSSL | High | Test each module combo in CI matrix |
| LTO runs out of memory in CI | Medium | Use larger runners or disable LTO in CI |
| Upstream merge conflicts | Low | Keep changes modular, clearly marked |
| RPM conflicts with official nginx | Medium | Use distinct package name (`centminmod-nginx`) |
| EL8 EOL (2029) | Low | Support EL8 while active, easy to drop later |

---

## Estimated Phase Effort

| Phase | Complexity | Key Challenge |
|-------|-----------|---------------|
| Phase 1 | Medium | Getting all spec paths and %files correct |
| Phase 2 | Medium | Module dependency management, source tarballs |
| Phase 3 | **High** | Custom crypto compilation inside rpmbuild |
| Phase 4 | Low-Medium | Straightforward, similar pattern to Phase 3 |
| Phase 5 | Medium | LTO memory requirements, PGO two-pass complexity |
| Phase 6 | Medium | CI pipeline orchestration, signing infrastructure |

---

---

## Dual-AI Plan Validation (Codex GPT-5.3 + Code-Searcher)

**Date**: 2026-03-27
**Confidence**: High Agreement — both AIs reached same core conclusions on all 10 validation questions.

### Critical Corrections to Incorporate

#### Correction 1: Phase 1 Scope Must Be Wider

Phase 1 must cover ALL files with hardcoded upstream paths, not just spec.in and Makefile:

| File | Lines | Hardcoded Path |
|------|-------|----------------|
| `rpm/SOURCES/nginx.service` | 9-12 | `/usr/sbin/nginx`, `/etc/nginx`, `/run/nginx.pid` |
| `rpm/SOURCES/nginx-debug.service` | 10 | `/usr/sbin/nginx-debug` |
| `rpm/SOURCES/nginx.upgrade.sh` | 10-11 | `/usr/sbin/nginx`, `/run/nginx.pid` |
| `rpm/SOURCES/nginx.check-reload.sh` | 11 | `/usr/sbin/nginx` |
| `rpm/SOURCES/nginx.conf` | 5, 15, 31 | `/var/log/nginx`, include paths |
| `rpm/SOURCES/nginx.default.conf` | 8 | root path |
| `rpm/SOURCES/logrotate` | 1, 11 | `/var/log/nginx/*.log`, PID path |
| `rpm/SPECS/nginx-module.spec.in` | 82, 135, 138, 155 | `nginx-r%{version}`, `%{_libdir}/nginx/modules` |
| All `Makefile.module-*` | `MODULE_POST_*` | User instructions referencing `/etc/nginx/nginx.conf` |
| `nginx.spec.in` | 293-305 | `%post` log file creation with `%{_localstatedir}/log/nginx` |

#### Correction 2: Use Custom Macros, NEVER Redefine Global RPM Macros

**CRITICAL**: Overriding `%{_libdir}`, `%{_sysconfdir}`, etc. will corrupt RPM debuginfo packaging. Instead:

```spec
%global cm_prefix       /usr/local/nginx
%global cm_confdir      %{cm_prefix}/conf
%global cm_sbindir      %{cm_prefix}/sbin
%global cm_moduledir    %{cm_prefix}/modules
%global cm_logdir       /var/log/nginx
%global cm_cachedir     /var/cache/nginx
```

Keep system macros (`%{_unitdir}`, `%{_mandir}`, `%{_libexecdir}`) for files that belong at system locations (systemd units, man pages, init scripts).

#### Correction 3: Fix Hidden Symlink Bug

`nginx.spec.in` lines 166-167 construct a relative symlink using string concatenation:
```spec
cd $RPM_BUILD_ROOT%{_sysconfdir}/nginx && \
    %{__ln_s} ../..%{_libdir}/nginx/modules modules
```
This will silently produce a **broken symlink** with custom paths. Rewrite to use absolute path or recalculate the relative path for `/usr/local/nginx`.

#### Correction 4: Crypto Toggle Model Refinement

Use **two complementary patterns**:
- `--define 'crypto awslc'` — for the 4-way crypto library selector (multi-value, not boolean)
- `%bcond_with` — for orthogonal boolean toggles: `quic`, `lto`, `mold`, `march_v3`, `zlib_ng`

Add `%%CRYPTO_PREBUILD%%` placeholder to `nginx.spec.in` `%build` section (before `./configure`).

Add fallback: `%{!?crypto: %define crypto system}` at spec top.

#### Correction 5: Package Naming + Module Dependency Fix

Rename to `centminmod-nginx` AND add virtual Provides for backward compat:
```spec
Name: centminmod-nginx
Provides: nginx-r%{base_version}
Provides: centminmod-nginx-r%{base_version}
```
This lets existing module spec `Requires: nginx-r%{base_version}` resolve without modifying every module spec file.

#### Correction 6: SELinux Under /usr/local

**Non-obvious risk**: SELinux labeling under `/usr/local` may not match what nginx expects for configs, modules, and logs. Add to Phase 1:
- `%post` script: `restorecon -R /usr/local/nginx` (if SELinux enabled)
- Or ship a custom SELinux policy module
- Document for users that `semanage fcontext` may be needed

#### Correction 7: GCC Toolset Activation Pattern

Use `. /opt/rh/gcc-toolset-N/enable` in `%build` section before `./configure`:
```spec
%build
%if 0%{?rhel} == 9
. /opt/rh/gcc-toolset-13/enable
%endif
```
Note: `%{optflags}` still reflects system defaults after sourcing — explicitly append `-O3`, `-march=x86-64-v2` to `WITH_CC_OPT`.

### Validated Decisions (Confirmed by Both AIs)

| Decision | Validation Status |
|----------|-------------------|
| 6-phase incremental approach | **Confirmed sound** — ordering 1→6 is correct |
| cmake pre-build for AWS-LC/BoringSSL | **Confirmed** — otel module pattern (Makefile.module-otel:41-127) is direct proof |
| `centminmod-nginx` package name | **Confirmed** — safer than custom release tag alone |
| GitHub Actions `container:` keyword for rpmbuild | **Confirmed** — simpler than Docker run, keep Dockerfiles for Sysbox systemd tests only |
| Dynamic modules as separate RPMs | **Confirmed** — module spec template handles this cleanly |
| Keeping upstream file structure for easy merges | **Confirmed** — extend rather than replace |

---

## Session Notes

* Development environment: macOS — all RPM build testing MUST be via Docker/GitHub Actions
* Never edit Centmin Mod codebase — read-only reference
* Always verify context7 docs when planning nginx configure flags or GitHub Actions patterns
* Keep upstream pkg-oss patterns where possible to ease future merges
* Test early, test often — Phase 1 CI workflow is the foundation for all other phases
* **NEW**: Never redefine global RPM macros (%{_libdir}, %{_sysconfdir}) — use custom cm_* macros
* **NEW**: Check SELinux labeling when using /usr/local paths in RPMs
* **NEW**: The modules symlink at spec.in lines 166-167 uses fragile relative path arithmetic — must fix
