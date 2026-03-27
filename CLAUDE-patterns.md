# Code Patterns and Conventions

## Upstream pkg-oss Patterns

### Spec Template Variable Substitution

The build system uses `%%VARIABLE%%` placeholders in `.spec.in` files, replaced by `sed` in the Makefile:

```makefile
# From rpm/SPECS/Makefile — spec generation pattern
sed -e 's#%%BASE_VERSION%%#$(BASE_VERSION)#g' \
    -e 's#%%BASE_RELEASE%%#$(BASE_RELEASE)#g' \
    -e 's#%%PACKAGE_VENDOR%%#$(PACKAGE_VENDOR)#g' \
    nginx.spec.in > nginx.spec
```

### Module Makefile Convention

Each module follows this naming and variable pattern:

```makefile
# File: Makefile.module-<name>
MODULE_VERSION_<NAME> = x.y.z
MODULE_SOURCES_<NAME> = <name>-$(MODULE_VERSION_<NAME>).tar.gz
MODULE_PATCHES_<NAME> = <name>/some.patch
MODULE_CONFARGS_<NAME> = --add-dynamic-module=<name>-$(MODULE_VERSION_<NAME>)
MODULE_DEFINITIONS_<NAME> = BuildRequires: some-devel
MODULE_FILES_<NAME> = %{_libdir}/nginx/modules/ngx_http_<name>_module.so
```

### OS-Conditional Logic in Spec Files

Distribution-specific handling uses RPM macros:

```spec
%if 0%{?rhel} == 7
# RHEL 7 specific
%endif

%if 0%{?rhel} >= 8
# RHEL 8+ specific (includes 9, 10)
%endif

%if 0%{?suse_version} >= 1315
# SUSE specific
%endif
```

### Debug + Release Build Pattern

Every package builds twice — once with `--with-debug`, once without:

```spec
%build
# Debug build
./configure ... --with-debug ...
make %{?_smp_mflags}
mv objs/nginx objs/nginx-debug
# Release build
./configure ...
make %{?_smp_mflags}
```

### Patch Collection Pattern

Patches are auto-discovered from `contrib/src/*/` directories:

```makefile
# Makefile collects patches, generates Patch001, Patch002, etc.
# Applied in %prep section with: %patch -P<N> -p1
```

## Centmin Mod Patterns (Reference)

### Variable Flag System

Centmin Mod uses simple shell variables for feature toggling:

```bash
# In /etc/centminmod/custom_config.inc or centmin.sh
NGINX_HTTP2='y'           # 'y' enables, 'n' disables
AWS_LC_SWITCH='n'         # Crypto library selection
NGXDYNAMIC_BROTLI='y'    # Dynamic module toggle
```

### Mutual Exclusivity for Crypto Libraries

Only one crypto library can be active — each sets others to 'n':

```bash
# If AWS_LC_SWITCH=y → OPENSSL_SYSTEM_USE=n, NGINX_QUIC_SUPPORT=n
# If BORINGSSL_SWITCH=y → OPENSSL_SYSTEM_USE=n, NGINX_FATLTO_OBJECTS=n
# If LIBRESSL_SWITCH=y → OPENSSL_SYSTEM_USE=n
```

### GCC Toolset Progression (Verified 2026-03-27)

**Centmin Mod current defaults** (from `centmin.sh:308-386`):
```bash
# EL7:  DEVTOOLSETSEVEN='y'      → devtoolset-7 (GCC 7.2)
# EL8:  DEVTOOLSETTHIRTEEN='y'   → gcc-toolset-13 (GCC 13.2) [EL8 >= 8.9]
# EL9:  DEVTOOLSETTHIRTEEN='y'   → gcc-toolset-13 (GCC 13.2) [EL9 >= 9.3]
# EL10: DEVTOOLSETFOURTEEN='y'   → gcc-toolset-14 (GCC 14.2)
# All:  DEVTOOLSETFIFTTEEN='n'   → gcc-toolset-15 defined but NOT yet enabled
```

**RPM build recommended** (latest available per platform):
```bash
# EL8:  gcc-toolset-14 (GCC 14.2.1) — latest on EL8 AppStream
# EL9:  gcc-toolset-15 (GCC 15.1.1) — available since RHEL 9.7
# EL10: System GCC 14.x (no toolset needed) or gcc-toolset-15 (GCC 15.1.1)
```

### GCC Toolset Activation in RPM Spec Files

```spec
# BuildRequires per EL version:
%if 0%{?rhel} == 8
BuildRequires: gcc-toolset-14-gcc gcc-toolset-14-gcc-c++
%endif
%if 0%{?rhel} == 9
BuildRequires: gcc-toolset-15-gcc gcc-toolset-15-gcc-c++
%endif

# Activation in %build (source enable script before ./configure):
%build
%if 0%{?rhel} == 8
. /opt/rh/gcc-toolset-14/enable
%endif
%if 0%{?rhel} == 9
. /opt/rh/gcc-toolset-15/enable
%endif
# EL10: system GCC 14 is sufficient — no enable needed
./configure ...
```

**Note**: `%{optflags}` still reflects system defaults after sourcing — explicitly append optimization flags to `WITH_CC_OPT`. RHEL 10 recommends `-D_FORTIFY_SOURCE=3` (not 2).

**References**: [GCC and gcc-toolset versions in RHEL](https://developers.redhat.com/articles/2025/04/16/gcc-and-gcc-toolset-versions-rhel-explainer) | [Red Hat GCC versions matrix](https://access.redhat.com/solutions/19458)

## Convention: When Adding New Modules

1. Create `Makefile.module-<name>` in `rpm/SPECS/`
2. Add source tarball to `contrib/src/<name>/` or `contrib/tarballs/`
3. Define all `MODULE_*_<NAME>` variables
4. Add module name to `MODULES` list in `rpm/SPECS/Makefile`
5. Test spec generation: `make nginx-module-<name>.spec`
6. Test build in AlmaLinux container

## Convention: When Modifying Configure Flags

* Edit `BASE_CONFIGURE_ARGS` in `rpm/SPECS/Makefile` for core flags
* Edit `MODULE_CONFARGS_*` in respective `Makefile.module-*` for module flags
* HTTP/3 flag (`--with-http_v3_module`) has OS-conditional exclusion for RHEL 7
