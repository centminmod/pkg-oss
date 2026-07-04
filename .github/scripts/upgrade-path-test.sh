#!/bin/bash
# Upgrade-path + variant-swap test against the published R2 repo, run inside
# an almalinux/<EL>-init container (systemd as PID 1 — the %postun hot-upgrade
# only fires when `service nginx status` succeeds).
#
# Phase A (upgrade path): the repo holds a single version per package, so the
# N-1 is synthesized — download the published base RPM, rpmrebuild it with a
# lowered Release (identical payload/scriptlets), install it, mark a
# %config(noreplace) file, `dnf update` to the real published package, then
# assert: release bumped, marker survived, hot-upgrade swapped the master PID
# while nginx kept serving, nginx -t clean, uninstall clean (.rpmsave kept).
#
# Phase B (variant swap, VARIANT=stable only): co-install of the SWAP_TO base
# must be refused (Conflicts), `dnf swap` + module reinstall from the new
# variant repo must succeed and nginx -V must report the new crypto lib.
#
# Env: VARIANT (default stable), EL (8|9|10), SWAP_TO (default awslc).
set -euo pipefail

VARIANT=${VARIANT:-stable}
EL=${EL:?EL env var required}
SWAP_TO=${SWAP_TO:-awslc}

PASS=0; FAIL=0; RESULTS=""
pass() { PASS=$((PASS+1)); RESULTS="${RESULTS}\n  PASS: $1"; echo "PASS: $1"; }
fail() { FAIL=$((FAIL+1)); RESULTS="${RESULTS}\n  FAIL: $1"; echo "FAIL: $1"; }

pkg_for_variant() {
  case "$1" in
    awslc|awslc-optimized|awslc-optimized-v4) echo "centminmod-nginx-awslc" ;;
    openssl)                                  echo "centminmod-nginx-openssl" ;;
    *)                                        echo "centminmod-nginx" ;;
  esac
}

# Write a repo file for a variant, with per-repo GPG signing detection
# (same migration bridge as test-rpm-repo.sh: unsigned repos get gpgcheck=0).
write_repo() {
  local variant=$1 id=$2
  local url="https://rpm-nginx.centminmod.com/${variant}/el/${EL}/\$basearch"
  local check="https://rpm-nginx.centminmod.com/${variant}/el/${EL}/x86_64"
  local gpgcheck=0 repo_gpgcheck=0 gpgkey_line=""
  if curl -sfo /dev/null "${check}/repodata/repomd.xml.asc"; then
    gpgcheck=1; repo_gpgcheck=1
    gpgkey_line="gpgkey=https://rpm-nginx.centminmod.com/RPM-GPG-KEY-centminmod-nginx"
    rpm --import https://rpm-nginx.centminmod.com/RPM-GPG-KEY-centminmod-nginx
    echo "${variant}/el${EL}: GPG-signed — gpgcheck=1 + repo_gpgcheck=1"
  else
    echo "WARNING: ${variant}/el${EL} not yet signed — gpgcheck disabled"
  fi
  cat > "/etc/yum.repos.d/${id}.repo" << REPOEOF
[${id}]
name=Centmin Mod Nginx ${variant} - EL${EL}
baseurl=${url}
enabled=1
gpgcheck=${gpgcheck}
repo_gpgcheck=${repo_gpgcheck}
${gpgkey_line}
metadata_expire=60
skip_if_unavailable=0
REPOEOF
}

PKG=$(pkg_for_variant "$VARIANT")
CONF=/usr/local/nginx/conf/nginx.conf
PIDFILE=/usr/local/nginx/logs/nginx.pid

echo "=========================================="
echo "Phase A: Upgrade path — ${VARIANT}/el${EL}"
echo "=========================================="

if ! curl -sfo /dev/null "https://rpm-nginx.centminmod.com/${VARIANT}/el/${EL}/x86_64/repodata/repomd.xml"; then
  echo "ERROR: ${VARIANT}/el${EL} repo not published — cannot run upgrade test"
  exit 1
fi

echo "--- Installing test prerequisites ---"
# initscripts provides /usr/sbin/service, which %postun needs for the
# hot-upgrade (initscripts-service on EL9/10, initscripts on EL8)
dnf -y install epel-release dnf-plugins-core procps-ng 2>&1 | tail -2
dnf -y install initscripts-service 2>/dev/null || dnf -y install initscripts 2>&1 | tail -1
dnf -y install rpmrebuild rpm-build 2>&1 | tail -2

# EL8 modular filtering blocks nginx-related packages; disable the module stream
dnf module disable -y nginx 2>/dev/null || true

write_repo "$VARIANT" centminmod-nginx-test
# -y: auto-accept the repo GPG key import (repo_gpgcheck keyring is separate
# from the rpmdb, so the rpm --import above does not cover metadata checks)
dnf -y makecache 2>&1 | tail -2

echo "--- Synthesizing N-1 from the published RPM ---"
mkdir -p /tmp/rpms
dnf download "$PKG" --downloaddir=/tmp/rpms 2>&1 | tail -2
CUR_RPM=$(find /tmp/rpms -name "${PKG}-[0-9]*.rpm" | head -1)
[ -n "$CUR_RPM" ] || { echo "ERROR: dnf download produced no RPM"; exit 1; }
CUR_VER=$(rpm -qp --qf '%{VERSION}' "$CUR_RPM")
CUR_REL=$(rpm -qp --qf '%{RELEASE}' "$CUR_RPM")
OLD_REL="0.${CUR_REL}"
echo "Published: ${PKG}-${CUR_VER}-${CUR_REL} — synthesizing ${PKG}-${CUR_VER}-${OLD_REL}"

rpmrebuild --notest-install \
  --change-spec-preamble="sed -e 's/^Release:.*/Release: ${OLD_REL}/'" \
  -p "$CUR_RPM" 2>&1 | tail -3
OLD_RPM=$(find /root/rpmbuild/RPMS -name "${PKG}-${CUR_VER}-${OLD_REL}.*.rpm" | head -1)
[ -n "$OLD_RPM" ] || { echo "ERROR: rpmrebuild did not produce the N-1 RPM"; exit 1; }

echo "--- Installing N-1 + headers-more module ---"
# headers-more comes from the repo (base hard-Requires it); the local N-1 is
# unsigned by construction, so keep localpkg_gpgcheck off explicitly
dnf -y install --setopt=localpkg_gpgcheck=0 "$OLD_RPM" nginx-module-headers-more 2>&1 | tail -3

INST_REL=$(rpm -q --qf '%{RELEASE}' "$PKG")
if [ "$INST_REL" = "$OLD_REL" ]; then pass "N-1 installed (${CUR_VER}-${OLD_REL})"; else fail "N-1 release mismatch: ${INST_REL}"; fi

MARKER="# upgrade-path-test-marker-$$"
echo "$MARKER" >> "$CONF"

echo "--- Starting nginx via systemd ---"
systemctl enable --now nginx
sleep 2
if systemctl is-active --quiet nginx; then pass "nginx active before upgrade"; else fail "nginx not active before upgrade"; systemctl status nginx --no-pager || true; fi
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/ || true)
if [ "$HTTP_CODE" != "000" ] && [ -n "$HTTP_CODE" ]; then pass "serving before upgrade (HTTP ${HTTP_CODE})"; else fail "not serving before upgrade"; fi
OLD_PID=$(cat "$PIDFILE")

echo "--- dnf update to the published package ---"
dnf -y update "$PKG" 2>&1 | tail -5
sleep 3  # let the %postun hot-upgrade finish (USR2 → new master → QUIT old)

INST_REL=$(rpm -q --qf '%{RELEASE}' "$PKG")
if [ "$INST_REL" = "$CUR_REL" ]; then pass "updated to published ${CUR_VER}-${CUR_REL}"; else fail "update release mismatch: ${INST_REL}"; fi

if grep -qF "$MARKER" "$CONF"; then pass "%config(noreplace) marker survived update"; else fail "marker lost from nginx.conf"; fi
# N-1 payload is identical, so any .rpmnew means the config was clobbered
if [ ! -f "${CONF}.rpmnew" ]; then pass "no unexpected nginx.conf.rpmnew"; else fail "unexpected nginx.conf.rpmnew created"; fi

NEW_PID=$(cat "$PIDFILE" 2>/dev/null || true)
if [ -n "$NEW_PID" ] && [ "$NEW_PID" != "$OLD_PID" ]; then
  pass "hot-upgrade swapped master PID (${OLD_PID} → ${NEW_PID})"
else
  fail "hot-upgrade did not swap master PID (old=${OLD_PID} new=${NEW_PID:-none})"
fi
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/ || true)
if [ "$HTTP_CODE" != "000" ] && [ -n "$HTTP_CODE" ]; then pass "still serving after upgrade (HTTP ${HTTP_CODE})"; else fail "not serving after upgrade"; fi
if /usr/local/sbin/nginx -t 2>&1; then pass "nginx -t clean after upgrade"; else fail "nginx -t failed after upgrade"; fi

echo "--- Uninstall ---"
dnf -y remove "$PKG" nginx-module-headers-more 2>&1 | tail -3
sleep 2
if ! rpm -q "$PKG" > /dev/null 2>&1; then pass "package removed"; else fail "package still installed after remove"; fi
if [ ! -e /usr/local/sbin/nginx ]; then pass "nginx binary removed"; else fail "nginx binary left behind"; fi
if ! pgrep -x nginx > /dev/null 2>&1; then pass "no nginx processes after remove"; else fail "nginx processes still running after remove"; fi
if [ -f "${CONF}.rpmsave" ] && grep -qF "$MARKER" "${CONF}.rpmsave"; then
  pass "modified config preserved as nginx.conf.rpmsave"
else
  fail "nginx.conf.rpmsave missing or lost the marker"
fi

if [ "$VARIANT" = "stable" ]; then
  echo ""
  echo "=========================================="
  echo "Phase B: Variant swap — ${VARIANT} → ${SWAP_TO} on el${EL}"
  echo "=========================================="
  if ! curl -sfo /dev/null "https://rpm-nginx.centminmod.com/${SWAP_TO}/el/${EL}/x86_64/repodata/repomd.xml"; then
    echo "WARNING: ${SWAP_TO}/el${EL} repo not published — skipping variant-swap phase"
  else
    SWAP_PKG=$(pkg_for_variant "$SWAP_TO")

    echo "--- Fresh install of published ${PKG} ---"
    dnf -y install "$PKG" nginx-module-headers-more 2>&1 | tail -3
    write_repo "$SWAP_TO" centminmod-nginx-swap
    dnf -y makecache 2>&1 | tail -2

    echo "--- Co-install of ${SWAP_PKG} must be refused ---"
    RC=0
    OUT=$(dnf -y install "$SWAP_PKG" 2>&1) || RC=$?
    if [ "$RC" -ne 0 ]; then pass "co-install refused (rc=${RC})"; else fail "co-install of ${SWAP_PKG} unexpectedly succeeded"; fi
    if echo "$OUT" | grep -qi "conflict"; then pass "dnf reported a package conflict"; else fail "no conflict in dnf output: $(echo "$OUT" | tail -3)"; fi
    if ! rpm -q "$SWAP_PKG" > /dev/null 2>&1; then pass "${SWAP_PKG} not installed after refusal"; else fail "${SWAP_PKG} ended up installed"; fi

    echo "--- dnf swap with only the ${SWAP_TO} repo enabled ---"
    rm -f /etc/yum.repos.d/centminmod-nginx-test.repo
    dnf clean expire-cache > /dev/null 2>&1 || true
    dnf -y swap "$PKG" "$SWAP_PKG" 2>&1 | tail -5
    if rpm -q "$SWAP_PKG" > /dev/null 2>&1 && ! rpm -q "$PKG" > /dev/null 2>&1; then
      pass "dnf swap ${PKG} → ${SWAP_PKG}"
    else
      fail "dnf swap did not leave exactly ${SWAP_PKG} installed"
    fi

    # Same module NEVRA exists in both variant repos but the payloads differ
    # (built per-variant) — reinstall pulls the ${SWAP_TO}-built module
    echo "--- Reinstall modules from the ${SWAP_TO} repo ---"
    dnf -y reinstall nginx-module-headers-more 2>&1 | tail -2 || \
      dnf -y distro-sync nginx-module-headers-more 2>&1 | tail -2

    case "$SWAP_TO" in
      awslc*)
        if /usr/local/sbin/nginx -V 2>&1 | grep -qiE "aws-?lc"; then
          pass "nginx -V reports AWS-LC after swap"
        else
          fail "nginx -V does not report AWS-LC after swap"
        fi ;;
      *) echo "INFO: no crypto-string check defined for ${SWAP_TO}" ;;
    esac
    if /usr/local/sbin/nginx -t 2>&1; then pass "nginx -t clean after swap"; else fail "nginx -t failed after swap"; fi
  fi
fi

echo ""
echo "=========================================="
echo "Results — upgrade path ${VARIANT}/el${EL}"
echo "=========================================="
TOTAL=$((PASS + FAIL))
echo "  Passed: ${PASS}/${TOTAL}"
echo "  Failed: ${FAIL}/${TOTAL}"
echo -e "Detailed results:${RESULTS}"

if [ $FAIL -gt 0 ]; then
  echo "FAIL: ${FAIL} test(s) failed"
  exit 1
fi
echo "ALL UPGRADE-PATH TESTS PASSED for ${VARIANT}/el${EL}"
