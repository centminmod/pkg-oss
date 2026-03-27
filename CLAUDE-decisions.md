# Architecture Decisions

## Decision 1: Fork nginx/pkg-oss Rather Than Build From Scratch

**Date**: 2026-03-27
**Status**: Accepted

**Context**: Centmin Mod currently source-compiles nginx via shell scripts (`inc/nginx_configure.inc`). The goal is to produce proper RPM packages instead.

**Decision**: Fork the upstream nginx/pkg-oss repository and modify it, rather than writing RPM spec files from scratch.

**Rationale**:
* pkg-oss already has a mature, production-tested RPM build infrastructure
* Handles multi-OS conditionals (RHEL 7-10), debug builds, module packaging
* Maintains spec template system with variable substitution
* Includes 19 dynamic module build configs as starting points
* Reduces risk of RPM packaging bugs

**Trade-offs**:
* Must track upstream changes and merge periodically
* pkg-oss paths/conventions differ from Centmin Mod (will need significant modification)
* Some pkg-oss features (NGINX Plus, SUSE, Alpine, Debian) are irrelevant but present

## Decision 2: RPM Focus Only — Ignore Alpine/Debian Directories

**Date**: 2026-03-27
**Status**: Accepted

**Context**: pkg-oss supports Alpine, Debian, and RPM packaging.

**Decision**: Only modify `rpm/` directory contents. Leave `alpine/` and `debian/` untouched.

**Rationale**: Centmin Mod targets RPM-based distros only (AlmaLinux, Rocky, CentOS).

## Decision 3: Docker-Based CI for All RPM Testing

**Date**: 2026-03-27
**Status**: Accepted

**Context**: Development happens on macOS which cannot run rpmbuild natively.

**Decision**: All RPM builds and testing run inside Docker containers via GitHub Actions, targeting AlmaLinux 8, 9, 10.

**Rationale**:
* macOS cannot natively build RPMs
* Docker + Sysbox provides systemd support for full integration testing
* GitHub Actions provides free CI minutes
* AlmaLinux `-init` images support systemd out of the box
* Existing Centmin Mod workflows (193 total) provide proven patterns

**Implementation**: See CLAUDE-nginx-rpm-ci-workflows.md for patterns and templates.

## Decision 4: Separate RPM Build and Integration Test Workflows

**Date**: 2026-03-27
**Status**: Accepted

**Decision**: Create separate GitHub Actions workflows — one for rpmbuild (produce RPMs), another for installing and validating them.

**Rationale**:
* Faster iteration — can test spec file changes without full stack validation
* RPM build failures are different from runtime failures
* Allows matrix strategy per EL version independently

## Decision 5: Maintain Upstream Compatibility Where Possible

**Date**: 2026-03-27
**Status**: Accepted

**Decision**: Keep upstream spec template structure and Makefile patterns. Extend rather than replace.

**Rationale**:
* Easier to merge upstream updates
* Proven patterns reduce packaging errors
* Module Makefile convention (`Makefile.module-*`) is clean and extensible

## Resolved Decisions (Validated 2026-03-27 by Dual-AI Review)

### Decision 6: Path Convention — Custom Macros with /usr/local/nginx

**Date**: 2026-03-27
**Status**: Accepted (Validated by Codex GPT-5.3 + Code-Searcher)

**Decision**: Use Centmin Mod paths (`/usr/local/nginx`) but implement via **custom named macros**, NOT by redefining global RPM macros.

**Implementation**:
```spec
%global cm_prefix       /usr/local/nginx
%global cm_confdir      %{cm_prefix}/conf
%global cm_sbindir      %{cm_prefix}/sbin
%global cm_moduledir    %{cm_prefix}/modules
%global cm_logdir       /var/log/nginx
```

**Rationale**: Redefining `%{_libdir}`, `%{_sysconfdir}` globally corrupts RPM debuginfo packaging machinery. Custom macros are surgical and safe. System macros (`%{_unitdir}`, `%{_mandir}`) stay valid for files that belong at system locations.

**Risk**: SELinux labeling under `/usr/local` may need `restorecon` or custom policy. Add to `%post` script.

### Decision 7: Crypto Library Toggle — --define for Selector, %bcond for Booleans

**Date**: 2026-03-27
**Status**: Accepted (Validated by Codex GPT-5.3 + Code-Searcher)

**Decision**: Use `rpmbuild --define 'crypto awslc'` for the 4-way crypto library selector (multi-value). Use `%bcond_with` for orthogonal boolean feature toggles (`quic`, `lto`, `mold`, `march_v3`, `zlib_ng`).

**Implementation**:
```spec
%{!?crypto: %define crypto system}
%bcond_with lto
%bcond_with mold
%bcond_with march_v3
%bcond_with zlib_ng
```

**Rationale**: Crypto selection is a multi-value choice (exactly one of 4 options), not a boolean. `%bcond_with/%bcond_without` is the wrong shape for that. But it's perfect for orthogonal on/off features. This split keeps the spec readable and type-correct.

### Decision 8: Package Naming — centminmod-nginx with Virtual Provides

**Date**: 2026-03-27
**Status**: Accepted (Validated by Codex GPT-5.3 + Code-Searcher)

**Decision**: Rename to `centminmod-nginx` and add `Provides: nginx-r%{base_version}` so module specs resolve dependencies without modification.

**Rationale**: Avoids `yum`/`dnf` conflicts with upstream nginx packages. The virtual Provides preserves backward compat with module spec's `Requires: nginx-r%{base_version}`.

### Decision 9: GCC Toolset Activation in Spec (Updated with Verified Versions)

**Date**: 2026-03-27
**Status**: Accepted (Updated with verified gcc-toolset versions)

**Decision**: Source the enable script in `%build` section. Use the **latest available** toolset per platform:

| OS | Toolset | GCC Version | Enable Path | System GCC |
|----|---------|-------------|-------------|-----------|
| EL8 | gcc-toolset-14 | 14.2.1 | `/opt/rh/gcc-toolset-14/enable` | 8.5 |
| EL9 | gcc-toolset-15 | 15.1.1 | `/opt/rh/gcc-toolset-15/enable` | 11.x |
| EL10 | System GCC (or gcc-toolset-15) | 14.x (or 15.1.1) | N/A | **14.x** |

**Key insight**: EL10's system GCC is already 14.x — gcc-toolset is optional, not required.

**Centmin Mod comparison**: Centmin Mod currently uses gcc-toolset-13 on EL8/9 and gcc-toolset-14 on EL10. Our RPM builds use newer toolsets (14/15) for better optimization.

**RHEL 10 hardening**: Red Hat now recommends `-D_FORTIFY_SOURCE=3` (not 2) and `-fstack-clash-protection` for RHEL 10 builds.

**`%{optflags}` caveat**: After sourcing the toolset, `%{optflags}` still reflects system defaults. Explicitly append `-O3` and other optimization flags to `WITH_CC_OPT`.

**References**:
- [GCC and gcc-toolset versions in RHEL](https://developers.redhat.com/articles/2025/04/16/gcc-and-gcc-toolset-versions-rhel-explainer)
- [RHEL 10.1 Release Notes — GCC Toolset 15](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/en/documentation/Red_Hat_Enterprise_Linux/10/html/10.1_release_notes/overview)
- [RHEL 10 Hardening (-D_FORTIFY_SOURCE=3)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/en/documentation/Red_Hat_Enterprise_Linux/10/html/developing_c_and_cpp_applications_in_rhel_10/creating-c-or-cpp-applications)
- [Red Hat GCC versions matrix](https://access.redhat.com/solutions/19458)

### Decision 10: CI Pattern — container: for rpmbuild, Dockerfiles for Sysbox

**Date**: 2026-03-27
**Status**: Accepted (Validated by Codex GPT-5.3 + Code-Searcher)

**Decision**: Use GitHub Actions `container:` keyword for normal rpmbuild matrix builds. Keep separate Dockerfile-based jobs only for Sysbox/systemd integration testing.

**Rationale**: `container:` is simpler, repo already uses this pattern in ci.yml, and it handles workspace mounting automatically.

## Pending Decisions

### Crypto Library Packaging Strategy

**Context**: Centmin Mod supports 4 crypto libraries. How to handle in RPM?

**Options**:
1. Separate spec files per crypto library (nginx-openssl, nginx-awslc, nginx-boringssl)
2. Single spec with build-time conditionals (e.g., `rpmbuild --define 'crypto awslc'`)
3. Always bundle custom OpenSSL in the RPM

**Leaning toward**: Option 2 for flexibility without spec file proliferation.

### Module Packaging: Bundled vs Separate RPMs

**Context**: Centmin Mod has 46+ modules. Upstream packages each as separate RPM.

**Options**:
1. Follow upstream — each module as separate nginx-module-* RPM
2. Bundle common modules into the base package (fewer RPMs to manage)
3. Hybrid — core modules bundled, optional ones as separate RPMs

**Leaning toward**: Option 3 to keep common modules easy to install while allowing optional ones.
