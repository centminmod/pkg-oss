# Nginx RPM Build CI Workflows — Decisions & Patterns

Documentation of CI/CD strategy, decisions, and reusable patterns for testing Centmin Mod Nginx RPM builds via GitHub Actions.

---

## Environment Constraints

- **Development machine**: macOS — **no local RPM builds possible**
- **Testing strategy**: Docker-based GitHub Actions targeting AlmaLinux 8, 9, 10
- **CI templates source**: `/Users/george/D7378/PC/gitrepos/www_git/centminmod-workflows/`
- **Target repo**: `centminmod/pkg-oss` (branch: `centminmod`)

---

## Existing Centmin Mod Workflow Patterns (193 workflows)

### Infrastructure Stack

| Component | Choice | Notes |
|-----------|--------|-------|
| Runner | `ubuntu-24.04` | Pinned version |
| Container runtime | Sysbox v0.6.7 (`sysbox-runc`) | Required for systemd in Docker |
| Docker buildx | `docker/setup-buildx-action@v3` | Multi-platform support |
| Image build | `docker/build-push-action@v6` | Layer caching |
| Artifacts | `actions/upload-artifact@v4` or `v7` | RPM uploads |
| Notifications | Discord webhook | Success/failure via `secrets.DISCORD_WEBHOOK_URL` |
| Orchestration | `peter-evans/repository-dispatch@v4` | Cross-workflow triggering |

### Base Docker Images

All use `-init` variants for systemd support:
```
almalinux/8-init
almalinux/9-init
almalinux/10-init
rockylinux/8-init
rockylinux/9-init
```

### Dockerfile Pattern (Systemd-Ready Container)

```dockerfile
FROM almalinux/9-init
ENV TERM=xterm-256color
ENV container=docker

# Install base packages
RUN dnf clean all && dnf -y update && \
    dnf -y install initscripts systemd-sysv systemd-devel \
    dos2unix python3 iptables iproute kmod procps-ng sudo udev

# Unmask systemd services for Docker
RUN systemctl unmask \
    systemd-remount-fs.service \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    systemd-logind.service \
    getty.target \
    console-getty.service

# Journal configuration
RUN echo "ReadKMsg=no" >> /etc/systemd/journald.conf

# Cleanup
RUN dnf clean all && rm -rf /var/cache/dnf/* /var/log/* /tmp/*

VOLUME [ "/sys/fs/cgroup", "/run" ]
CMD ["/sbin/init"]
```

### Docker Run Command

**EL8/EL9:**
```bash
docker run --cgroupns host -d --name=cmm_el89 \
  --runtime=sysbox-runc \
  --cap-add=SYS_ADMIN \
  --security-opt seccomp=unconfined \
  --security-opt label=disable \
  --security-opt apparmor=unconfined \
  -v /tmp/$(mktemp -d):/run \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  cmm_el89:latest
```

**EL10 (additional flags):**
```bash
docker run --cgroupns host -d --name=cmm_el10 \
  --privileged \
  --runtime=sysbox-runc \
  --cap-add=SYS_ADMIN \
  --cap-add=SYS_RESOURCE \
  --tmpfs /run \
  --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  cmm_el10:latest
```

### Matrix Strategy Pattern

```yaml
strategy:
  fail-fast: false
  matrix:
    el_version: ${{ fromJSON(
      github.event.inputs.el_versions == 'el10' && '[10]' ||
      github.event.inputs.el_versions == 'el9' && '[9]' ||
      github.event.inputs.el_versions == 'el8' && '[8]' ||
      github.event.inputs.el_versions == 'el9-el10' && '[9, 10]' ||
      github.event.inputs.el_versions == 'el8-el9-el10' && '[8, 9, 10]' ||
      '[10]'
    ) }}
```

### RPM Build Pattern (from build-pure-ftpd-el10.yml)

```yaml
- name: Build Docker image
  run: docker build -f docker/Dockerfile.rpmbuild-el${{ matrix.el_version }} -t rpmbuild:latest .

- name: Create build directory
  run: mkdir -p output

- name: Run rpmbuild container
  run: |
    docker run --rm \
      -v ${{ github.workspace }}/output:/output \
      rpmbuild:latest \
      bash -c "cd /home/builder/rpmbuild; rpmbuild -ba SPECS/nginx.spec; cp RPMS/*/* /output/;"

- name: Upload RPM artifacts
  uses: actions/upload-artifact@v4
  with:
    name: nginx-rpms-el${{ matrix.el_version }}
    path: output/*.rpm
```

### RPM Build Dependencies

```bash
# Base build tools (all EL versions):
dnf -y groupinstall 'Development Tools'
dnf -y install zlib-devel bzip2-devel openssl-devel systemd-devel \
  wget tar gzip xz xz-devel zstd-devel cmake3 rpm-build pcre2-devel

# GCC Toolset per EL version (verified 2026-03-27):
# EL8: gcc-toolset-14 (GCC 14.2.1)
dnf -y install gcc-toolset-14-gcc gcc-toolset-14-gcc-c++

# EL9: gcc-toolset-15 (GCC 15.1.1) — available since RHEL/AlmaLinux 9.7
dnf -y install gcc-toolset-15-gcc gcc-toolset-15-gcc-c++

# EL10: System GCC 14.x is sufficient — no gcc-toolset needed
# Optionally: dnf -y install gcc-toolset-15-gcc gcc-toolset-15-gcc-c++
```

**References**:
- [RHEL 8 Additional Toolsets](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/developing_c_and_cpp_applications_in_rhel_8/additional-toolsets-for-development_developing-applications)
- [RHEL 9 Additional Toolsets](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/developing_c_and_cpp_applications_in_rhel_9/assembly_additional-toolsets-for-development-rhel-9_developing-applications)
- [gcc-toolset-15 in AlmaLinux Git](https://git.almalinux.org/rpms/gcc-toolset-15)

### Feature Customization Pattern

Workflows write feature flags to `/etc/centminmod/custom_config.inc`:
```bash
echo 'AWS_LC_SWITCH=y' >> /etc/centminmod/custom_config.inc
echo 'OPENSSL_SYSTEM_USE=n' >> /etc/centminmod/custom_config.inc
echo 'NGINX_LTO_FORCE=y' >> /etc/centminmod/custom_config.inc
```

### Log Collection Pattern

```yaml
- name: Copy logs from container
  run: |
    mkdir -p ./buildlogs
    docker exec container_name tar -C /path/to/logs -cf - . | tar -C ./buildlogs -xf -

- name: Upload logs
  uses: actions/upload-artifact@v4
  with:
    name: build-logs-el${{ matrix.el_version }}
    path: buildlogs/*
```

### Validation Pattern (continue-on-error)

```yaml
- name: Check nginx binary
  continue-on-error: true
  run: docker exec container_name nginx -V

- name: Check nginx config
  continue-on-error: true
  run: docker exec container_name nginx -t
```

### Discord Notification Pattern

```yaml
discordNotificationSuccess:
  needs: build
  if: ${{ success() }}
  runs-on: ubuntu-latest
  steps:
    - name: Notify Discord
      run: |
        curl -H "Content-Type: application/json" -X POST \
          -d "{\"content\":\"${{ github.workflow }} completed successfully!\"}" \
          ${{ secrets.DISCORD_WEBHOOK_URL }}
```

---

## GitHub Secrets Required

| Secret | Purpose |
|--------|---------|
| `PAT` | Personal Access Token for workflow triggering |
| `DISCORD_WEBHOOK_URL` | Discord notifications |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 (RPM hosting) |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 |
| `R2_ENDPOINT` | Cloudflare R2 endpoint |

---

## Decisions

### Decision 1: Target OS Matrix
**Choice**: AlmaLinux 8, 9, 10 only (not Rocky/Oracle for initial RPM builds)
**Why**: Centmin Mod's primary target; can expand later. Matches existing CI patterns.

### Decision 2: Sysbox Runtime for Systemd
**Choice**: Use Sysbox v0.6.7 for containers requiring systemd
**Why**: Proven pattern from 193 existing workflows. Required for proper service testing.

### Decision 3: RPM Build vs Integration Test Separation
**Choice**: Separate workflows — rpmbuild workflows (produce RPMs) + integration test workflows (install & validate RPMs)
**Why**: Faster iteration. RPM build can be tested without full stack. Integration tests validate installed RPMs work correctly.

### Decision 4: Artifact Storage
**Choice**: GitHub Actions artifacts for CI, Cloudflare R2 for distribution
**Why**: Existing infrastructure. R2 already used for Centmin Mod RPM parts.

### Decision 5: EL10 Requires --privileged + Extra Capabilities
**Choice**: Use `--privileged --cap-add=SYS_RESOURCE --tmpfs /run --tmpfs /run/lock` for EL10
**Why**: EL10 containers need additional privileges for systemd. Also needs `Storage=volatile` in journald.conf.

---

## Planned Workflow Structure

```
.github/workflows/
├── build-nginx-rpm.yml              # Matrix build: rpmbuild for EL 8/9/10
├── test-nginx-rpm-install.yml       # Install built RPMs and validate
├── build-nginx-rpm-http3.yml        # HTTP/3 variant (custom OpenSSL/AWS-LC)
├── build-nginx-rpm-modules.yml      # Build dynamic module RPMs
└── manual-trigger-all.yml           # Orchestration workflow
```

### Workflow 1: build-nginx-rpm.yml (Core)
```yaml
on:
  workflow_dispatch:
    inputs:
      el_versions:
        type: choice
        options: [el10, el9, el8, el9-el10, el8-el9-el10]
      nginx_version:
        type: string
        default: '1.29.7'

jobs:
  build:
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        el_version: [8, 9, 10]  # or from inputs
    steps:
      - checkout
      - setup Sysbox
      - setup Docker Buildx
      - build rpmbuild Docker image for EL${{ matrix.el_version }}
      - run rpmbuild -ba SPECS/nginx.spec
      - collect RPM artifacts
      - upload artifacts
      - Discord notification
```

### Workflow 2: test-nginx-rpm-install.yml
```yaml
jobs:
  test:
    needs: [build]  # or workflow_dispatch with artifact download
    steps:
      - start AlmaLinux container (sysbox-runc)
      - install built RPMs via dnf localinstall
      - validate nginx -V output
      - validate nginx -t config test
      - validate systemctl start/stop/reload
      - validate dynamic module loading
      - check binary for expected compile flags
      - upload validation logs
```

---

## Testing Checklist for RPM Validation

- [ ] `rpm -qi nginx` — package info matches expected version/release
- [ ] `nginx -V` — configure flags match expected set
- [ ] `nginx -t` — config validation passes
- [ ] `systemctl start nginx` — service starts cleanly
- [ ] `systemctl reload nginx` — graceful reload works
- [ ] `curl http://localhost/` — serves default page
- [ ] `ldd /usr/sbin/nginx` — linked libraries are correct
- [ ] Dynamic modules load without errors
- [ ] Debug binary exists and works (`/usr/sbin/nginx-debug`)
- [ ] Log rotation config is present
- [ ] Correct user/group ownership (nginx:nginx)
- [ ] File permissions are correct
- [ ] `rpm -V nginx` — no modified files after fresh install
