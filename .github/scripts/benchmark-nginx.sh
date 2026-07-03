#!/bin/bash
# Quick in-container ab (HTTP/1.1) + h2load (HTTP/2+TLS) benchmark of the
# freshly built RPMs. Env: BENCH_LABEL (display label for log grouping).
# Exits 1 only when nginx fails to start or h2load has 0 succeeded requests.
set -euo pipefail

BENCH_LABEL=${BENCH_LABEL:-}

echo "=== Installing nginx for benchmark ==="
# shellcheck disable=SC2010  # RPM filenames are safe; preserve original ls|grep pipeline
main_rpm=$(ls /output/centminmod-nginx*-[0-9]*.x86_64.rpm 2>/dev/null | grep -v debuginfo | grep -v module | head -1) || true
rpm -ivh --nodeps "$main_rpm" 2>&1 | tail -3
# Install module RPMs (nginx.conf uses more_set_headers which needs headers-more)
for rpm_file in /output/nginx-module-*.x86_64.rpm; do
  [ -f "$rpm_file" ] || continue
  if echo "$rpm_file" | grep -q debuginfo; then continue; fi
  rpm -ivh --nodeps "$rpm_file" 2>&1 | tail -1
done
dnf -y install httpd-tools nghttp2 openssl 2>&1 | tail -5

# Generate self-signed TLS cert for HTTP/2 benchmark
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout /tmp/bench.key -out /tmp/bench.crt \
  -subj "/CN=localhost" 2>&1 || true
ls -la /tmp/bench.crt /tmp/bench.key 2>/dev/null || echo "WARNING: TLS cert generation failed"
mkdir -p /usr/local/nginx/conf/conf.d
printf "server {\n    listen 8443 ssl;\n    http2 on;\n    server_name localhost;\n    ssl_certificate /tmp/bench.crt;\n    ssl_certificate_key /tmp/bench.key;\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_session_cache shared:SSL:10m;\n    location / {\n        root /usr/local/nginx/html;\n    }\n}\n" > /usr/local/nginx/conf/conf.d/bench-ssl.conf

BENCH_ERRORS=0

/usr/local/sbin/nginx || true
sleep 1

# Verify nginx started
NGINX_PID="/usr/local/nginx/logs/nginx.pid"
if ! [ -f "$NGINX_PID" ] || ! kill -0 "$(cat "$NGINX_PID")" 2>/dev/null; then
  echo "ERROR: nginx failed to start for benchmark"
  echo "--- nginx error log ---"
  cat /usr/local/nginx/logs/error.log 2>/dev/null || true
  BENCH_ERRORS=1
else
  echo "PASS: nginx started successfully (PID $(cat "$NGINX_PID"))"
fi

echo ""
echo "=========================================="
echo "=== HTTP/1.1 BENCHMARK (ab)            ==="
echo "=== ${BENCH_LABEL} ==="
echo "=========================================="
if [ -f "$NGINX_PID" ] && kill -0 "$(cat "$NGINX_PID")" 2>/dev/null; then
  ab -n 10000 -c 50 http://127.0.0.1:80/ > /dev/null 2>&1 || true
  for run in 1 2 3; do
    echo ""
    echo "--- HTTP/1.1 run ${run}/3 ---"
    ab -n 100000 -c 100 http://127.0.0.1:80/ 2>&1 | grep -E "Requests per second|Time per request|Transfer rate|Complete requests|Failed requests" || true
  done
else
  echo "SKIP: nginx not running"
fi

echo ""
echo "=========================================="
echo "=== HTTP/2+TLS BENCHMARK (h2load)      ==="
echo "=== ${BENCH_LABEL} ==="
echo "=========================================="
if [ -f "$NGINX_PID" ] && kill -0 "$(cat "$NGINX_PID")" 2>/dev/null; then
  h2load -n 10000 -c 50 -m 50 -t 4 https://127.0.0.1:8443/ > /dev/null 2>&1 || true
  for run in 1 2 3; do
    echo ""
    echo "--- HTTP/2+TLS run ${run}/3 ---"
    h2load -n 100000 -c 100 -m 50 -t 4 https://127.0.0.1:8443/ 2>&1 | tee "/tmp/h2load_run${run}.txt" | grep -E "finished in|requests:|req/s|time for request|time for connect|status codes" || true
    # Check for 100% failed requests
    if grep -qE ", 0 succeeded," "/tmp/h2load_run${run}.txt" 2>/dev/null; then
      echo "ERROR: h2load run ${run} had 0 succeeded requests"
      BENCH_ERRORS=1
    fi
  done
else
  echo "SKIP: nginx not running"
  BENCH_ERRORS=1
fi

/usr/local/sbin/nginx -s quit 2>/dev/null || true
echo ""
if [ "$BENCH_ERRORS" -gt 0 ]; then
  echo "=== Benchmark completed with ERRORS ==="
  exit 1
else
  echo "=== Benchmark complete ==="
fi
