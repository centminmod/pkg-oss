# Troubleshooting Guide

## Build System Issues

### rpmbuild Fails with Missing BuildRequires

**Symptom**: `rpmbuild -ba nginx.spec` fails with unresolved dependencies.

**Fix**: Install build dependencies first:

```bash
# Generate spec, then install deps
cd rpm/SPECS && make nginx.spec
dnf -y builddep ./nginx.spec
```

### Spec Generation Fails — "No such file" for Patches

**Symptom**: `make nginx.spec` fails because patch files in `contrib/src/` are missing.

**Fix**: Ensure contrib sources are fetched:

```bash
cd contrib && make fetch
```

### Module Spec Won't Generate

**Symptom**: `make nginx-module-<name>.spec` produces empty or error output.

**Check**: Ensure `Makefile.module-<name>` exists in `rpm/SPECS/` and defines all required `MODULE_*_<NAME>` variables.

### RHEL 7 Build Fails with HTTP/3

**Symptom**: Build error related to `--with-http_v3_module` on RHEL 7 / CentOS 7.

**Cause**: HTTP/3 requires OpenSSL >= 1.1.1 with QUIC support. RHEL 7 ships OpenSSL 1.0.2.

**Fix**: The upstream spec conditionally excludes HTTP/3 for RHEL 7. Ensure the conditional is present:

```spec
%if 0%{?rhel} >= 8
--with-http_v3_module
%endif
```

### EL10 Container Fails to Start systemd

**Symptom**: Docker container for AlmaLinux 10 hangs or systemd doesn't initialize.

**Fix**: EL10 requires additional Docker flags:

```bash
docker run --cgroupns host -d \
  --privileged \
  --runtime=sysbox-runc \
  --cap-add=SYS_ADMIN \
  --cap-add=SYS_RESOURCE \
  --tmpfs /run \
  --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  almalinux/10-init:latest
```

Also add to journald.conf: `Storage=volatile`

### Never Redefine Global RPM Macros for Custom Paths

**Mistake**: Redefining `%{_libdir}`, `%{_sysconfdir}`, `%{_sbindir}` at the top of the spec to change installation paths.

**Symptom**: debuginfo package generation fails or produces corrupt debuginfo RPMs. Other RPM machinery (dependency generators, file triggers) may also break.

**Fix**: Use custom named macros instead:
```spec
%global cm_prefix       /usr/local/nginx
%global cm_confdir      %{cm_prefix}/conf
%global cm_sbindir      %{cm_prefix}/sbin
%global cm_moduledir    %{cm_prefix}/modules
```

Keep system macros for files at standard locations (systemd units, man pages, logrotate).

### Broken Symlink After Changing Module Path

**Symptom**: `/usr/local/nginx/conf/modules` symlink points to nonexistent target after path changes.

**Cause**: `nginx.spec.in` lines 166-167 construct relative symlink via string concatenation (`../..` + `%{_libdir}`). When paths change, the arithmetic breaks silently.

**Fix**: Use absolute path in the symlink or recalculate the relative path:
```spec
%{__ln_s} %{cm_moduledir} $RPM_BUILD_ROOT%{cm_confdir}/modules
```

### SELinux Labeling Under /usr/local

**Symptom**: nginx fails to read configs, load modules, or write logs after RPM install on SELinux-enforcing systems.

**Cause**: `/usr/local` paths may have wrong SELinux context labels.

**Fix**: Add `restorecon -R /usr/local/nginx` to `%post` script, or ship a custom SELinux policy module.

### gcc-toolset-15 Not Available on EL8

**Symptom**: `dnf install gcc-toolset-15-gcc` fails on AlmaLinux/RHEL 8.

**Cause**: gcc-toolset-15 is only available on RHEL/AlmaLinux 9.7+ and 10.1+. Not backported to EL8.

**Fix**: Use gcc-toolset-14 (GCC 14.2.1) on EL8 — that's the latest available.

```bash
# EL8: use gcc-toolset-14
dnf -y install gcc-toolset-14-gcc gcc-toolset-14-gcc-c++
. /opt/rh/gcc-toolset-14/enable

# EL9: use gcc-toolset-15
dnf -y install gcc-toolset-15-gcc gcc-toolset-15-gcc-c++
. /opt/rh/gcc-toolset-15/enable
```

### EL10 System GCC Is Already 14.x — gcc-toolset-14 Is Redundant

**Symptom**: Installing gcc-toolset-14 on EL10 has no practical benefit.

**Cause**: RHEL/AlmaLinux 10's system GCC is already version 14.x. gcc-toolset-14 provides the same GCC version.

**Fix**: On EL10, either use system GCC directly (no toolset needed) or install gcc-toolset-15 for GCC 15.1.1:

```bash
# Option 1: Use system GCC 14 (recommended — simpler)
gcc -v  # Already shows GCC 14.x

# Option 2: Use gcc-toolset-15 for GCC 15.1.1
dnf -y install gcc-toolset-15-gcc gcc-toolset-15-gcc-c++
. /opt/rh/gcc-toolset-15/enable
```

**Reference**: [GCC and gcc-toolset versions in RHEL](https://developers.redhat.com/articles/2025/04/16/gcc-and-gcc-toolset-versions-rhel-explainer)

## Common Pitfalls

### Editing .spec Instead of .spec.in

**Mistake**: Modifying `nginx.spec` directly — changes are overwritten by `make nginx.spec`.

**Correct**: Always edit `nginx.spec.in` (the template) or the Makefile variables that generate the spec.

### Forgetting to Update Module Version in Both Places

**Mistake**: Updating module version in `Makefile.module-*` but not in `contrib/src/<module>/version`.

**Check**: Version files in `contrib/src/` and `MODULE_VERSION_*` in Makefiles must match.

### Patch Numbering Conflicts

**Symptom**: Patches fail to apply with "already applied" or "offset" errors.

**Cause**: Patch numbers are auto-generated. Adding patches to `contrib/src/` changes the numbering.

**Fix**: Run `make clean && make nginx.spec` to regenerate with correct numbering.

## CI/CD Issues

### Sysbox Installation Fails on GitHub Runner

**Fix**: Pin Sysbox version and ensure dpkg installation:

```bash
curl -LO https://downloads.nestybox.com/sysbox/releases/v0.6.7/sysbox-ce_0.6.7-0.linux_amd64.deb
sudo dpkg -i sysbox-ce_0.6.7-0.linux_amd64.deb
```

### Docker Build Cache Issues

**Symptom**: Dockerfile changes not picked up in CI.

**Fix**: Use `docker/build-push-action@v6` with explicit `no-cache: true` or invalidate layers.

### Renaming RPM Package Breaks Source0, autosetup, and bdir

**Symptom**: `rpmbuild -ba nginx.spec` fails with "Bad exit status from .../prep" or source tarball not found after changing `Name: nginx` to `Name: centminmod-nginx`.

**Cause**: Three locations in nginx.spec.in use `%{name}` which expands to the new package name:
- `Source0: %{name}-%{version}.tar.gz` → tries to download `centminmod-nginx-1.29.7.tar.gz` (doesn't exist)
- `%autosetup -p1` → looks for directory `centminmod-nginx-1.29.7/` (tarball has `nginx-1.29.7/`)
- `%define bdir %{_builddir}/%{name}-%{base_version}` → wrong build directory path

**Fix**: Hardcode `nginx` in all three:
```spec
Source0: https://nginx.org/download/nginx-%{base_version}.tar.gz
%autosetup -n nginx-%{base_version} -p1
%define bdir %{_builddir}/nginx-%{base_version}
```

### RPM Comments Don't Suppress Macro Expansion

**Symptom**: `error: line 166: %package debuginfo: package centminmod-nginx-debuginfo already exists`

**Cause**: Lines like `#%debug_package` or `#%define _debugsource_template %{nil}` are expanded by rpmbuild even though they're "commented out" with `#`. RPM's `#` only suppresses the directive — macros inside are still expanded. `#%debug_package` creates a debuginfo subpackage, conflicting with the auto-generated one.

**Fix**: Delete commented-out macro lines entirely. Never comment out RPM macros — remove them or wrap in `%if 0`.

### Docker Volume Permission Denied for RPM Output

**Symptom**: `cp: cannot create regular file '/output/foo.rpm': Permission denied` when copying built RPMs to Docker volume mount.

**Cause**: `mkdir -p output` on the host creates the directory owned by `runner`. The Docker container runs as `builder` (non-root) and can't write to it.

**Fix**: `chmod 777 output` before `docker run`:
```yaml
run: mkdir -p output && chmod 777 output && docker run --rm -v ${{ github.workspace }}/output:/output ...
```

### Docker Build Missing docs/ Directory

**Symptom**: `cd: ../../docs: No such file or directory` during `make nginx.spec`.

**Cause**: The Makefile's `nginx.rpm-changelog` target runs `cd $(DOCS)` where `DOCS?= ../../docs` is relative to the original repo layout. Dockerfiles that only copy `rpm/SPECS/` and `contrib/` are missing `docs/`.

**Fix**: Add `COPY docs/ /home/builder/docs/` to Dockerfile and pass `DOCS=/home/builder/docs` to make.

### Modules Symlink Unnecessary with Custom Prefix

**Symptom**: Broken symlink at `/usr/local/nginx/conf/modules` after Phase 1 path changes.

**Cause**: Upstream creates a symlink from `%{_sysconfdir}/nginx/modules → %{_libdir}/nginx/modules` because modules-path and prefix are in different directory trees. With `--prefix=/usr/local/nginx` and `--modules-path=/usr/local/nginx/modules`, the modules dir is already under the prefix.

**Fix**: Remove the symlink creation entirely. Just `%{__mkdir} -p $RPM_BUILD_ROOT%{cm_moduledir}`.
