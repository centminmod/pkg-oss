#!/bin/bash
# Install base nginx + all module RPMs inside the rpmbuild:elN container and
# verify every non-debug module .so loads via nginx -t (NDK loaded first).
set -euo pipefail

# Install base nginx + all module RPMs
# shellcheck disable=SC2010  # RPM filenames are safe; preserve original ls|grep pipeline
main_rpm=$(ls /output/centminmod-nginx*-[0-9]*.x86_64.rpm 2>/dev/null | grep -v debuginfo | grep -v module | head -1) || true
rpm -ivh --nodeps "$main_rpm" 2>&1
for rpm_file in /output/nginx-module-*.x86_64.rpm; do
  [ -f "$rpm_file" ] || continue
  if echo "$rpm_file" | grep -q debuginfo; then continue; fi
  if echo "$rpm_file" | grep -q "\.src\.rpm"; then continue; fi
  rpm -ivh --nodeps "$rpm_file" 2>&1
done

NGINX_BIN=/usr/local/sbin/nginx
MODULE_DIR=/usr/local/nginx/modules

echo ""
echo "=== nginx -V before module load test ==="
$NGINX_BIN -V 2>&1
echo ""

# Build load_module config — NDK must load first (lua, encrypted-session, set-misc depend on it)
# Skip -debug.so files (only loadable by nginx-debug binary)
MODULES_CONF=/tmp/modules-load-test.conf
echo "# Auto-generated module load test" > "$MODULES_CONF"

# NDK first (dependency for other modules)
if [ -f "$MODULE_DIR/ndk_http_module.so" ]; then
  echo "load_module $MODULE_DIR/ndk_http_module.so;" >> "$MODULES_CONF"
fi

# All other non-debug modules (skip ndk — already loaded above)
for so in "$MODULE_DIR"/*.so; do
  [ -f "$so" ] || continue
  if basename "$so" | grep -q "\-debug\.so$"; then continue; fi
  if basename "$so" | grep -q "^ndk_http_module.so$"; then continue; fi
  echo "load_module $so;" >> "$MODULES_CONF"
done

echo "=== Module load_module directives ==="
cat "$MODULES_CONF"
DIRECTIVE_COUNT=$(grep -c "^load_module" "$MODULES_CONF") || true
echo ""
echo "Total load_module directives: $DIRECTIVE_COUNT"

# Create minimal test config that includes modules
TEST_CONF=/tmp/nginx-module-test.conf
cat "$MODULES_CONF" > "$TEST_CONF"
cat >> "$TEST_CONF" << NGINX_CONF
events {
    worker_connections 64;
}
http {
    server {
        listen 127.0.0.1:18080;
        server_name localhost;
        location / { return 200 "ok"; }
    }
}
NGINX_CONF

echo ""
echo "=== nginx -t (module load test) ==="
LOAD_PASS=0; LOAD_FAIL=0; FAILED_MODULES=""
if $NGINX_BIN -t -c "$TEST_CONF" 2>&1; then
  echo ""
  echo "PASS: All $DIRECTIVE_COUNT modules loaded successfully"
  LOAD_PASS=$DIRECTIVE_COUNT
else
  echo ""
  echo "WARN: Some modules failed to load, testing individually..."
  # Test each module individually to identify failures
  for so in "$MODULE_DIR"/*.so; do
    [ -f "$so" ] || continue
    MOD_NAME=$(basename "$so")
    if echo "$MOD_NAME" | grep -q "\-debug\.so$"; then continue; fi
    SINGLE_CONF=/tmp/test-single.conf
    # NDK-dependent modules need ndk loaded first
    if echo "$MOD_NAME" | grep -qE "(lua|encrypted_session|set_misc)"; then
      echo "load_module $MODULE_DIR/ndk_http_module.so;" > "$SINGLE_CONF"
    else
      : > "$SINGLE_CONF"
    fi
    echo "load_module $so;" >> "$SINGLE_CONF"
    cat >> "$SINGLE_CONF" << NGINX_CONF2
events { worker_connections 64; }
http { server { listen 127.0.0.1:18080; server_name localhost; location / { return 200 ok; } } }
NGINX_CONF2
    if $NGINX_BIN -t -c "$SINGLE_CONF" 2>&1; then
      LOAD_PASS=$((LOAD_PASS+1))
    else
      echo "FAIL to load: $MOD_NAME"
      $NGINX_BIN -t -c "$SINGLE_CONF" 2>&1 || true
      LOAD_FAIL=$((LOAD_FAIL+1))
      FAILED_MODULES="$FAILED_MODULES $MOD_NAME"
    fi
  done
  echo ""
  echo "=== Individual module load results: $LOAD_PASS passed, $LOAD_FAIL failed ==="
  if [ -n "$FAILED_MODULES" ]; then echo "Failed modules:$FAILED_MODULES"; fi
fi

echo ""
echo "=== nginx -V after module load test ==="
$NGINX_BIN -V 2>&1
echo ""
echo "=== nginx -T (effective config with modules) ==="
$NGINX_BIN -T -c "$TEST_CONF" 2>&1
