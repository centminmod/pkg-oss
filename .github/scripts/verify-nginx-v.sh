#!/bin/bash
# Verify nginx -V output inside the rpmbuild:elN container: GCC version,
# compiler/linker/FORTIFY flags, and (env-driven) LTO / -march / mold checks.
# Env: LTO (y|n), MARCH (generic|x86-64-v3|x86-64-v4), LINKER (default|mold).
# For non-optimized builds the defaults assert the ABSENCE of optimization flags.
set -euo pipefail

LTO=${LTO:-n}
MARCH=${MARCH:-generic}
LINKER=${LINKER:-default}

echo "=== Installing RPM and running nginx -V ==="
# shellcheck disable=SC2010  # RPM filenames are safe; preserve original ls|grep pipeline
main_rpm=$(ls /output/centminmod-nginx*-[0-9]*.x86_64.rpm 2>/dev/null | grep -v debuginfo | head -1) || true
if [ -z "$main_rpm" ]; then
  echo "FAIL: main RPM not found"
  exit 1
fi
rpm -ivh --nodeps "$main_rpm" 2>&1
echo ""
echo ":: nginx -V ::"
NGINX_V=$(/usr/local/sbin/nginx -V 2>&1)
echo "$NGINX_V"
echo ""
echo ":: nginx -t (base only, modules not loaded yet — may fail) ::"
/usr/local/sbin/nginx -t 2>&1 || echo "(expected: shipped config requires dynamic modules)"
echo ""
echo "=== Compiler verification ==="
PASS=0
FAIL=0
echo ":: Checking GCC version in built binary ::"
if echo "$NGINX_V" | grep -qiE "gcc [0-9]+\.[0-9]+"; then
  GCC_USED=$(echo "$NGINX_V" | grep -oiE "gcc [0-9]+\.[0-9]+\.[0-9]+" | head -1)
  echo "Built with: $GCC_USED"
  EL_VERSION=$(rpm -E '%{rhel}')
  case "$EL_VERSION" in
    8) EXPECTED_GCC="14" ;;
    9) EXPECTED_GCC="15" ;;
    10) EXPECTED_GCC="15" ;;
    *) EXPECTED_GCC="" ;;
  esac
  if echo "$GCC_USED" | grep -q "gcc ${EXPECTED_GCC}\."; then
    echo "PASS: GCC major version matches expected ($EXPECTED_GCC) for EL${EL_VERSION}"
    PASS=$((PASS+1))
  else
    echo "WARN: GCC version mismatch - expected GCC ${EXPECTED_GCC}, got $GCC_USED"
    FAIL=$((FAIL+1))
  fi
fi
echo ""
echo ":: Checking compiler flags in nginx -V ::"
for flag in "-O3" "-fstack-protector-strong" "-fstack-clash-protection" "-Wimplicit-fallthrough=0" "--param=ssp-buffer-size=4"; do
  if echo "$NGINX_V" | grep -q -- "$flag"; then
    echo "PASS: $flag found"
    PASS=$((PASS+1))
  else
    echo "FAIL: $flag NOT found"
    FAIL=$((FAIL+1))
  fi
done
echo ""
echo ":: Checking FORTIFY_SOURCE level ::"
EL_VERSION=$(rpm -E '%{rhel}')
if [ "$EL_VERSION" = "10" ]; then
  EXPECTED_FORTIFY="FORTIFY_SOURCE=3"
else
  EXPECTED_FORTIFY="FORTIFY_SOURCE=2"
fi
if echo "$NGINX_V" | grep -q "$EXPECTED_FORTIFY"; then
  echo "PASS: $EXPECTED_FORTIFY found (correct for EL${EL_VERSION})"
  PASS=$((PASS+1))
else
  echo "FAIL: $EXPECTED_FORTIFY NOT found"
  FAIL=$((FAIL+1))
fi
echo ""
echo ":: Checking linker flags ::"
for flag in "--as-needed" "-Bsymbolic-functions"; do
  if echo "$NGINX_V" | grep -q -- "$flag"; then
    echo "PASS: $flag found"
    PASS=$((PASS+1))
  else
    echo "FAIL: $flag NOT found"
    FAIL=$((FAIL+1))
  fi
done
echo ""
echo "=== Optimization verification ==="
echo ":: Checking LTO flags (LTO='${LTO}') ::"
if [ "$LTO" = "y" ]; then
  if echo "$NGINX_V" | grep -q -- "-flto=auto"; then
    echo "PASS: -flto=auto found (LTO enabled)"
    PASS=$((PASS+1))
  else
    echo "FAIL: -flto=auto NOT found but LTO=y was requested"
    FAIL=$((FAIL+1))
  fi
else
  if echo "$NGINX_V" | grep -q -- "-flto"; then
    echo "FAIL: -flto found but LTO=n (should not be present)"
    FAIL=$((FAIL+1))
  else
    echo "PASS: No -flto flag (LTO disabled as expected)"
    PASS=$((PASS+1))
  fi
fi
echo ""
echo ":: Checking MARCH flags (MARCH='${MARCH}') ::"
if [ "$MARCH" != "generic" ]; then
  if echo "$NGINX_V" | grep -q -- "-march=${MARCH}"; then
    echo "PASS: -march=${MARCH} found"
    PASS=$((PASS+1))
  else
    echo "FAIL: -march=${MARCH} NOT found"
    FAIL=$((FAIL+1))
  fi
else
  if echo "$NGINX_V" | grep -q -- "-march="; then
    echo "FAIL: -march= found but MARCH=generic (should not be present)"
    FAIL=$((FAIL+1))
  else
    echo "PASS: No -march= flag (generic as expected)"
    PASS=$((PASS+1))
  fi
fi
echo ""
echo ":: Checking LINKER flags (LINKER='${LINKER}') ::"
if [ "$LINKER" = "mold" ]; then
  if echo "$NGINX_V" | grep -q -- "-fuse-ld=mold"; then
    echo "PASS: -fuse-ld=mold found (mold linker enabled)"
    PASS=$((PASS+1))
  else
    echo "FAIL: -fuse-ld=mold NOT found but LINKER=mold was requested"
    FAIL=$((FAIL+1))
  fi
else
  if echo "$NGINX_V" | grep -q -- "-fuse-ld=mold"; then
    echo "FAIL: -fuse-ld=mold found but LINKER=default (should not be present)"
    FAIL=$((FAIL+1))
  else
    echo "PASS: No -fuse-ld=mold flag (default linker as expected)"
    PASS=$((PASS+1))
  fi
fi
echo ""
echo "=== Verification summary: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "WARNING: Some verification checks failed"
fi
