# Centmin Mod Nginx RPM Packages

[![Build Status](https://img.shields.io/github/actions/workflow/status/centminmod/pkg-oss/build-nginx-rpm.yml?branch=centminmod&label=RPM%20Build)](https://github.com/centminmod/pkg-oss/actions/workflows/build-nginx-rpm.yml)
[![Nginx Version](https://img.shields.io/badge/nginx-1.29.7-green)](https://nginx.org/)
[![License](https://img.shields.io/badge/license-BSD--2--Clause-blue)](LICENSE)

Production-grade Nginx RPM packages for **AlmaLinux/Rocky Linux 8, 9, and 10**, built with [Centmin Mod](https://centminmod.com/) optimizations: custom crypto libraries, 26 dynamic modules, GCC toolsets, LTO, and advanced compiler flags.

**RPM Repository**: `https://rpm-nginx.centminmod.com`

## Quick Install

```bash
# AlmaLinux/Rocky Linux 8/9/10
cat > /etc/yum.repos.d/centminmod-nginx.repo << 'EOF'
[centminmod-nginx]
name=Centmin Mod Nginx - EL$releasever - $basearch
baseurl=https://rpm-nginx.centminmod.com/stable/el/$releasever/$basearch/
enabled=1
gpgcheck=0
metadata_expire=60
EOF

# EL8 only: disable nginx module stream to avoid conflicts
dnf module disable -y nginx

# Install nginx + all modules
dnf install -y centminmod-nginx nginx-module-*
```

## Overview

This is a fork of [nginx/pkg-oss](https://github.com/nginx/pkg-oss) (the official Nginx packaging repository) adapted to produce Centmin Mod-flavored Nginx RPMs. The build system has been extended with:

- **Custom crypto libraries**: System OpenSSL, [AWS-LC](https://github.com/aws/aws-lc), or custom OpenSSL (from source)
- **26 dynamic modules** as separate RPM packages
- **GCC toolsets**: GCC 14 (EL8), GCC 15 (EL9, EL10)
- **Compiler optimizations**: `-O3`, `-fstack-protector-strong`, `-fstack-clash-protection`
- **Optional LTO**: Link-Time Optimization via `-flto=auto`
- **Optional mold linker**: Faster linking via `-fuse-ld=mold`
- **Microarchitecture targeting**: `-march=x86-64-v2`, `-march=x86-64-v3`, `-march=x86-64-v4`
- **Centmin Mod paths**: `/usr/local/nginx/`, `/usr/local/sbin/nginx`
- **Centmin Mod configs**: 19 default config files, `dynamic-modules.d/` drop-in module loading
- **Cloudflare R2 repository**: `rpm-nginx.centminmod.com` with automated `dnf install` testing

## Repository Variants

RPMs are published to `rpm-nginx.centminmod.com` in variant-separated directories:

| Variant | Base URL | Crypto | Description |
|---------|----------|--------|-------------|
| **stable** | `/stable/el/{8,9,10}/x86_64/` | System OpenSSL | Default, recommended for most users |
| **awslc** | `/awslc/el/{8,9,10}/x86_64/` | [AWS-LC](https://github.com/aws/aws-lc) | AWS crypto library, FIPS-capable |
| **openssl** | `/openssl/el/{8,9,10}/x86_64/` | Custom OpenSSL 3.5.x | Built from source with custom options |
| **optimized** | `/optimized/el/{8,9,10}/x86_64/` | System OpenSSL | LTO + `-march=x86-64-v3` + mold linker (Haswell 2013+) |
| **optimized-v4** | `/optimized-v4/el/{8,9,10}/x86_64/` | System OpenSSL | LTO + `-march=x86-64-v4` + mold linker (Skylake-X / Zen 4+, AVX-512) |

Each variant includes:
- 1 base package: `centminmod-nginx` (or `centminmod-nginx-awslc`, `centminmod-nginx-openssl`)
- 26 module packages: `nginx-module-{name}`
- Debug info packages

## Included Modules

All 26 modules are built as separate RPM packages (`nginx-module-{name}`):

| Module | Description |
|--------|-------------|
| **accesskey** | Access key-based authorization |
| **brotli** | Brotli compression (2 .so files) |
| **cache-purge** | Cache purge via URL |
| **dav-ext** | WebDAV extended methods |
| **echo** | Echo/testing module |
| **encrypted-session** | Encrypted session variables |
| **fancyindex** | Fancy directory listing |
| **geoip2** | MaxMind GeoIP2 database support |
| **headers-more** | Custom HTTP headers (required dependency) |
| **http-concat** | Concatenate files in a single response |
| **http-rdns** | Reverse DNS lookups |
| **http-redis** | Redis caching |
| **image-filter** | On-the-fly image processing |
| **length-hiding** | Response length padding |
| **lua** | Lua scripting (OpenResty) |
| **memc** | Memcached module |
| **ndk** | Nginx Development Kit (dependency for lua, set-misc, encrypted-session) |
| **njs** | Nginx JavaScript (njs 0.9.6) |
| **redis2** | Redis 2.0 protocol |
| **set-misc** | Set and manipulate variables |
| **srcache** | Subrequest-based caching |
| **subs-filter** | Response body substitution |
| **testcookie** | Bot detection via cookie challenge |
| **vts** | Virtual host traffic status |
| **xslt** | XML/XSLT transformation |
| **zstd** | Zstandard compression (2 .so files) |

## Prerequisites

Most dependencies are resolved automatically by dnf when installing module RPMs. Some modules require system libraries:

| System Package | Required By | Notes |
|---|---|---|
| `procps-ng` | centminmod-nginx (base) | Explicit RPM dependency |
| `brotli` | nginx-module-brotli | Auto-resolved by dnf |
| `libmaxminddb` | nginx-module-geoip2 | Auto-resolved by dnf |
| `gd` | nginx-module-image-filter | Auto-resolved by dnf |
| `libxslt` | nginx-module-xslt, nginx-module-dav-ext | Auto-resolved by dnf |
| `libxml2` | nginx-module-xslt, nginx-module-dav-ext | Auto-resolved by dnf |
| `libzstd` | nginx-module-zstd | Auto-resolved by dnf |

On minimal installs, pre-install all prerequisites:

```bash
dnf install -y procps-ng brotli libmaxminddb gd libxslt libxml2 libzstd
```

**EL8 only:** Run `dnf module disable -y nginx` before installing to avoid modular filtering conflicts.

**Module dependencies:** `nginx-module-lua`, `nginx-module-set-misc`, and `nginx-module-encrypted-session` require `nginx-module-ndk` — resolved automatically by dnf.

## Package Details

### Naming Convention

```
centminmod-nginx-1.29.7-1.el9.cmm.x86_64.rpm           # stable (system crypto)
centminmod-nginx-awslc-1.29.7-1.el9.cmm.x86_64.rpm     # AWS-LC crypto
centminmod-nginx-openssl-1.29.7-1.el9.cmm.x86_64.rpm   # custom OpenSSL
nginx-module-brotli-1.29.7+1.0.0-1.el9.ngx.x86_64.rpm  # module RPM
```

### Installation Paths

| Path | Purpose |
|------|---------|
| `/usr/local/sbin/nginx` | Nginx binary |
| `/usr/local/nginx/conf/` | Configuration directory |
| `/usr/local/nginx/conf/nginx.conf` | Main config |
| `/usr/local/nginx/conf/conf.d/` | Virtual host configs |
| `/usr/local/nginx/conf/dynamic-modules.d/` | Module load_module drop-in configs |
| `/usr/local/nginx/modules/` | Module .so files (62 total) |
| `/usr/local/nginx/html/` | Default document root |
| `/usr/local/nginx/logs/` | Log directory |

### Systemd Service

```bash
systemctl start nginx
systemctl enable nginx
systemctl reload nginx    # graceful reload
```

## Building from Source

### Requirements

RPM builds run inside Docker containers (AlmaLinux 8/9/10). You do NOT need an RPM build environment locally — GitHub Actions handles everything.

### Build Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **Build RPM** | `build-nginx-rpm.yml` | Base + module RPMs with crypto/zlib selection |
| **Build RPM (Optimized)** | `build-nginx-rpm-optimized.yml` | LTO, mold linker, `-march` targeting |
| **Build RPM (AutoFDO)** | `build-nginx-rpm-autofdo.yml` | AutoFDO profile-guided optimization (POC) |
| **Build RPM (BOLT)** | `build-nginx-rpm-bolt.yml` | BOLT post-link binary optimization (POC) |
| **Publish to R2** | `publish-rpm-repo.yml` | Upload RPMs to Cloudflare R2 + `dnf install` test |
| **Test RPM Repository** | `test-rpm-repo.yml` | Functional test all 26 modules from live R2 repo |
| **Benchmark Compare** | `benchmark-compare.yml` | h2load benchmark: base vs optimized |
| **Benchmark Compare v4** | `benchmark-compare-v4-ubicloud.yml` | h2load benchmark on AVX-512 Ubicloud runners |

All build workflows also have Ubicloud variants (`*-ubicloud.yml`) that run on AVX-512 capable runners for `x86-64-v4` builds.

### Triggering a Build

Via GitHub Actions UI or CLI:

```bash
# Standard build (Cloudflare zlib default)
gh workflow run build-nginx-rpm.yml -f el_versions=el9 -f crypto=system

# AWS-LC crypto
gh workflow run build-nginx-rpm.yml -f el_versions=el9 -f crypto=awslc

# Optimized (LTO + march + mold)
gh workflow run build-nginx-rpm-optimized.yml -f el_versions=el9 \
  -f crypto=system -f lto=y -f march=x86-64-v3 -f linker=mold

# Test all variants from live R2 repo
gh workflow run test-rpm-repo.yml -f variants=stable,awslc,openssl,optimized,optimized-v4
```

### Build Inputs

| Input | Options | Default | Description |
|-------|---------|---------|-------------|
| `el_versions` | el8, el9, el10, el9-el10, el8-el9-el10 | el9 | Target EL version(s) |
| `crypto` | system, awslc, openssl | system | Crypto library |
| `zlib` | cloudflare, system | cloudflare | Compression library ([Cloudflare zlib](https://github.com/nicholasjackson/cloudflare-zlib) SIMD-accelerated) |
| `lto` | n, y | n | Link-Time Optimization (optimized workflow) |
| `march` | generic, x86-64-v2, x86-64-v3, x86-64-v4 | generic | Microarchitecture target (optimized workflow) |
| `linker` | default, mold | default | Linker selection (optimized workflow) |

### Publishing to R2

After a successful build, publish RPMs to the R2 repository:

```bash
# Find latest successful build
RUN_ID=$(gh run list --workflow=build-nginx-rpm.yml --status=success --limit=1 \
  --json databaseId --jq '.[0].databaseId')

# Publish to R2
gh workflow run publish-rpm-repo.yml --ref master \
  -f variant=stable -f el_version=9 -f run_id=$RUN_ID
```

The publish workflow:
1. Downloads RPM artifacts from the build run
2. Verifies complete package set (1 base + 26 modules)
3. Generates YUM/DNF repository metadata via `createrepo_c`
4. Uploads to R2 in 4 ordered phases (RPMs, metadata, signature, entry point)
5. Purges CDN cache
6. Runs automated `dnf install` test from the live repository

## Compiler Configuration

### GCC Toolsets

| EL Version | System GCC | Toolset Used | GCC Version |
|------------|-----------|-------------|-------------|
| EL8 | 8.5 | gcc-toolset-14 | 14.2.1 |
| EL9 | 11.x | gcc-toolset-15 | 15.1.1 |
| EL10 | 14.x | System (no toolset) | 14.x |

### Compiler Flags

```
CC:  -O3 -g -fPIC -fstack-protector-strong -fstack-clash-protection
     -Wimplicit-fallthrough=0 -Wformat -Wformat-security
     -Wp,-D_FORTIFY_SOURCE=2 --param=ssp-buffer-size=4    # EL8/9
     -Wp,-D_FORTIFY_SOURCE=3                                # EL10

LD:  -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -Wl,-Bsymbolic-functions
```

### Crypto Library Options

| Option | Library | Notes |
|--------|---------|-------|
| `system` (default) | System OpenSSL | 3.0.x (EL9), 3.5.x (EL10) — HTTP/3 QUIC on EL9+ |
| `awslc` | AWS-LC | Statically linked, FIPS-capable |
| `openssl` | Custom OpenSSL 3.5.x | Built from source with `enable-ec_nistp_64_gcc_128 enable-tls1_3` |

## Architecture

### Build System Flow

```
Makefile (root)                    # Version management, release automation
  └── rpm/SPECS/Makefile           # RPM build orchestrator
        ├── nginx.spec.in          # Base spec template → nginx.spec
        ├── nginx-module.spec.in   # Module spec template → nginx-module-*.spec
        ├── Makefile.module-*      # 26 per-module build configs
        └── rpmbuild -ba *.spec    # RPM compilation in Docker
```

### Spec Template Variables

`nginx.spec.in` and `nginx-module.spec.in` use `%%VARIABLE%%` placeholders replaced by the Makefile at spec generation time:

- `%%BASE_VERSION%%` — nginx version
- `%%CRYPTO_PACKAGE_SUFFIX%%` — `-awslc`, `-openssl`, or empty
- `%%BASE_CONFIGURE_ARGS%%` — all `--with-*` configure flags
- `%%MODULE_CONFIGURE_ARGS%%` — module-specific configure flags
- `%%MODULE_PREINSTALL%%` — module drop-in config file creation

### Directory Layout

```
.github/workflows/          # CI/CD workflows (17 total)
rpm/SPECS/                   # Spec templates, Makefiles, module definitions
rpm/SOURCES/                 # nginx.conf, systemd services, config files
contrib/src/                 # Module source directories with patches
docker/                      # Dockerfile.rpmbuild-el{8,9,10}
docs/                        # XML changelogs for spec generation
```

## Upstream Relationship

This fork is based on `nginx/pkg-oss` and maintains merge compatibility:

- Centmin Mod changes are clearly scoped to RPM spec templates and Makefile
- Upstream module Makefile patterns are preserved
- `centminmod` branch contains all customizations
- Periodic `git merge origin/master` picks up new nginx versions

## License

[BSD 2-Clause](LICENSE)

Based on [nginx/pkg-oss](https://github.com/nginx/pkg-oss) by [F5, Inc.](https://www.f5.com/)

Centmin Mod customizations by [centminmod.com](https://centminmod.com/)
