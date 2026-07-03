#!/bin/bash
# Build dynamic module RPMs inside the rpmbuild:elN container.
# Env: CRYPTO, ZLIB, MODULES (blank = all BASE_MODULES), LTO, MARCH, LINKER, AUTOFDO.
# Individual module build failures are reported but do not fail the script —
# the verify steps and the publish workflow validate module counts downstream.
set -euo pipefail

CRYPTO=${CRYPTO:-system}
ZLIB=${ZLIB:-system}
LTO=${LTO:-n}
MARCH=${MARCH:-generic}
LINKER=${LINKER:-default}
AUTOFDO=${AUTOFDO:-none}
MODULES=${MODULES:-}

# Recreate nginx tarball symlink (needed by module-% prerequisite)
cd /home/builder/contrib && make .sum-nginx
ln -sf /home/builder/contrib/tarballs/nginx-*.tar.gz /home/builder/rpmbuild/SOURCES/
# Recreate crypto/zlib symlinks if needed
if [ "$CRYPTO" = "awslc" ]; then
  make .sum-awslc
  ln -sf /home/builder/contrib/tarballs/aws-lc-*.tar.gz /home/builder/rpmbuild/SOURCES/
fi
if [ "$CRYPTO" = "openssl" ]; then
  make .sum-openssl
  ln -sf /home/builder/contrib/tarballs/openssl-*.tar.gz /home/builder/rpmbuild/SOURCES/
fi
if [ "$ZLIB" = "cloudflare" ]; then
  make .sum-cf-zlib
  ln -sf /home/builder/contrib/tarballs/zlib-*.tar.gz /home/builder/rpmbuild/SOURCES/
fi
cd /home/builder/rpmbuild/SPECS
mkdir -p /tmp/module-logs
PASS=0; FAIL=0; FAILED=""
BUILD_START=$(date +%s)
ALL_MODULES="$(make -s echo-base-modules)"  # single source: BASE_MODULES in rpm/SPECS/Makefile
MODULES="${MODULES:-$ALL_MODULES}"
# headers-more is a hard Requires of the base RPM — always build it
echo "$MODULES" | grep -qw headers-more || MODULES="headers-more $MODULES"
# ndk is required by lua, encrypted-session, set-misc — auto-include if any are present
if echo "$MODULES" | grep -qw lua || echo "$MODULES" | grep -qw encrypted-session || echo "$MODULES" | grep -qw set-misc; then
  echo "$MODULES" | grep -qw ndk || MODULES="ndk $MODULES"
fi
echo "Building modules: $MODULES"
for mod in $MODULES; do
  echo ""; echo "===> Building module: ${mod}"
  MOD_START=$(date +%s)
  LOG="/tmp/module-logs/${mod}.log"
  RC=0
  make CONTRIB=/home/builder/contrib DOCS=/home/builder/docs \
    CRYPTO="${CRYPTO}" ZLIB="${ZLIB}" LTO="${LTO}" MARCH="${MARCH}" \
    LINKER="${LINKER}" AUTOFDO="${AUTOFDO}" \
    "module-${mod}" > "$LOG" 2>&1 || RC=$?
  MOD_END=$(date +%s)
  if [ $RC -eq 0 ]; then
    # Verify .so files were actually produced
    SO_COUNT=$(find ../RPMS -name "nginx-module-${mod}*.rpm" -newer "$LOG" 2>/dev/null | wc -l) || true
    echo "PASS: module-${mod} ($((MOD_END-MOD_START))s) [${SO_COUNT} RPMs]"
    PASS=$((PASS+1))
  else
    echo "FAIL: module-${mod} ($((MOD_END-MOD_START))s) [exit=$RC]"
    FAIL=$((FAIL+1))
    FAILED="${FAILED} ${mod}"
    echo "--- Failure diagnostics for ${mod} ---"
    # Show last 30 lines of build log for quick diagnosis
    echo "::group::${mod} build log (last 30 lines)"
    tail -30 "$LOG"
    echo "::endgroup::"
    # Check for common failure patterns
    if grep -q "No rule to make target.*rpm-changelog" "$LOG"; then
      echo "  CAUSE: Missing docs/nginx-module-${mod}.xml changelog file"
    fi
    if grep -q "Illegal char" "$LOG"; then
      echo "  CAUSE: Invalid character in RPM Version/Release field"
      grep "Illegal char" "$LOG"
    fi
    if grep -q "File not found:.*/modules/\*" "$LOG"; then
      echo "  CAUSE: No .so files produced — module may not support dynamic loading"
      echo "  Check: Does the module config file have ngx_module_type declaration?"
    fi
    if grep -q "error:.*No such file" "$LOG"; then
      echo "  CAUSE: Missing file at install time"
      grep "No such file" "$LOG" | tail -3
    fi
    if grep -q "configure: error" "$LOG"; then
      echo "  CAUSE: nginx configure failed"
      grep "configure: error" "$LOG" | tail -3
    fi
    if grep -qE "\.(c|cc|cpp):[0-9]+:[0-9]+: error:" "$LOG"; then
      echo "  CAUSE: Compilation error"
      grep -E "\.(c|cc|cpp):[0-9]+:[0-9]+: error:" "$LOG" | tail -5
    fi
    echo "--- End diagnostics for ${mod} ---"
  fi
done
BUILD_END=$(date +%s)
echo ""
echo "=========================================="
echo "=== MODULE BUILD SUMMARY ==="
echo "=========================================="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Total:  $((PASS+FAIL)) modules in $((BUILD_END-BUILD_START))s"
if [ -n "$FAILED" ]; then
  echo "  Failed:${FAILED}"
fi
echo "=========================================="
# Dump full njs log for debugging QuickJS detection issues
if [ -f /tmp/module-logs/njs.log ]; then
  echo ""
  echo "::group::Full njs module build log (for QuickJS debugging)"
  cat /tmp/module-logs/njs.log
  echo "::endgroup::"
fi
find ../RPMS ../SRPMS -name "*.rpm" -exec cp -v {} /output/ \;
