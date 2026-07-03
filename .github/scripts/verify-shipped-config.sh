#!/bin/bash
# Verify the shipped Centmin Mod config (Phase 7B) inside the rpmbuild:elN
# container: config files, dynamic-modules.d drop-ins, directories, nginx -t,
# and a start/stop smoke test. Exits 1 if any check fails.
set -euo pipefail

echo "=== Phase 7B: Verify shipped Centmin Mod config ==="
echo ""

# Debug: show what files are inside the headers-more module RPM
echo "=== Debug: headers-more RPM contents ==="
# shellcheck disable=SC2010  # RPM filenames are safe; preserve original ls|grep pipeline
hm_rpm=$(ls /output/nginx-module-headers-more*.x86_64.rpm 2>/dev/null | grep -v debuginfo | head -1) || true
if [ -n "$hm_rpm" ]; then
  rpm -qlp "$hm_rpm" 2>&1
else
  echo "headers-more RPM not found in output"
fi
echo ""

# Debug: show base RPM contents (config files)
echo "=== Debug: base RPM config files ==="
# shellcheck disable=SC2010  # RPM filenames are safe; preserve original ls|grep pipeline
main_rpm=$(ls /output/centminmod-nginx*-[0-9]*.x86_64.rpm 2>/dev/null | grep -v debuginfo | grep -v module | head -1) || true
rpm -qlp "$main_rpm" 2>&1 | grep -E "conf/|dynamic-modules" || true
echo ""

# Install base nginx + all module RPMs
rpm -ivh --nodeps "$main_rpm" 2>&1
for rpm_file in /output/nginx-module-*.x86_64.rpm; do
  [ -f "$rpm_file" ] || continue
  if echo "$rpm_file" | grep -q debuginfo; then continue; fi
  if echo "$rpm_file" | grep -q "\.src\.rpm"; then continue; fi
  rpm -ivh --nodeps "$rpm_file" 2>&1
done

CONFDIR=/usr/local/nginx/conf
PASS=0; FAIL=0

echo ""
echo "=== Verify config files exist ==="
for f in nginx.conf dynamic-modules.conf dynamic-modules-includes.conf \
         maintenance.conf sitestatus.conf webp.conf ssl_include.conf \
         fastcgi_param_https_map.conf normalize_encoding.conf \
         default_phpupstream.conf vts_http.conf vts_server.conf \
         vts_mainserver.conf geoip.conf pagespeedadmin.conf \
         drop.conf staticfiles.conf php.conf errorpage.conf phpstatus.conf; do
  if [ -f "$CONFDIR/$f" ]; then
    echo "PASS: $f exists"
    PASS=$((PASS+1))
  else
    echo "FAIL: $f MISSING"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== Verify dynamic-modules.d/ drop-in files ==="
if [ -d "$CONFDIR/dynamic-modules.d" ]; then
  echo "PASS: dynamic-modules.d/ directory exists"
  PASS=$((PASS+1))
  echo "Drop-in files:"
  ls -la "$CONFDIR/dynamic-modules.d/" 2>&1
  # shellcheck disable=SC2012  # count only; filenames are safe
  DROPIN_COUNT=$(ls "$CONFDIR/dynamic-modules.d/"*.conf 2>/dev/null | wc -l) || true
  echo "Total drop-in configs: $DROPIN_COUNT"
  if [ "$DROPIN_COUNT" -gt 0 ]; then
    echo "PASS: $DROPIN_COUNT drop-in files found"
    PASS=$((PASS+1))
    echo ""
    echo "Drop-in file contents:"
    for df in "$CONFDIR/dynamic-modules.d/"*.conf; do
      echo "--- $(basename "$df") ---"
      cat "$df"
    done
  else
    echo "FAIL: No drop-in files found"
    FAIL=$((FAIL+1))
  fi
else
  echo "FAIL: dynamic-modules.d/ directory missing"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Verify new directories ==="
for d in "$CONFDIR/ssl" "$CONFDIR/dynamic-modules.d" /var/log/nginx; do
  if [ -d "$d" ]; then
    echo "PASS: $d exists"
    PASS=$((PASS+1))
  else
    echo "FAIL: $d MISSING"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "=== nginx -t with shipped config (all modules loaded) ==="
if /usr/local/sbin/nginx -t 2>&1; then
  echo "PASS: nginx -t succeeded with shipped config"
  PASS=$((PASS+1))
else
  echo "FAIL: nginx -t failed with shipped config"
  FAIL=$((FAIL+1))
  echo ""
  echo "=== Debug: nginx -T (full config dump) ==="
  /usr/local/sbin/nginx -T 2>&1 || true
fi

echo ""
echo "=== nginx start/stop test ==="
if /usr/local/sbin/nginx 2>&1; then
  sleep 1
  if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    echo "PASS: curl localhost returned 200"
    PASS=$((PASS+1))
  else
    echo "WARN: curl localhost did not return 200"
  fi
  /usr/local/sbin/nginx -s stop 2>&1
  echo "PASS: nginx started and stopped successfully"
  PASS=$((PASS+1))
else
  echo "FAIL: nginx failed to start"
  FAIL=$((FAIL+1))
fi

echo ""
echo "========================================="
echo "Phase 7B Config Verification: $PASS passed, $FAIL failed"
echo "========================================="
if [ $FAIL -gt 0 ]; then
  echo "WARNING: Some config verification checks failed"
  exit 1
fi
