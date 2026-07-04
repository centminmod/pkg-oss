#!/bin/bash
# One benchmark-compare scenario inside the rpmbuild:elN container.
# Env: SCENARIO (A|B|C|D), SCENARIO_LABEL, LOAD_MODULES (y|n),
#      REQUESTS, CLIENTS, STREAMS, RUNS.
# RPMs are mounted at /rpms; results go to /output/bench-${SCENARIO}.txt.
#
# Uses a self-contained bench config (-c) instead of the shipped nginx.conf:
# the Phase 7B shipped config hard-requires headers-more (more_set_headers)
# and auto-loads every installed module via dynamic-modules.d drop-ins, which
# broke the old inline scenarios (unknown directive on module-less installs,
# duplicate load_module on full installs). With-modules scenarios load all
# installed modules through the shipped dynamic-modules.conf include.
set -euo pipefail

SCENARIO=${SCENARIO:?SCENARIO env var required}
SCENARIO_LABEL=${SCENARIO_LABEL:-$SCENARIO}
LOAD_MODULES=${LOAD_MODULES:-n}
REQUESTS=${REQUESTS:-100000}
CLIENTS=${CLIENTS:-100}
STREAMS=${STREAMS:-10}
RUNS=${RUNS:-3}

# Install base nginx RPM (+ all module RPMs for with-modules scenarios)
# shellcheck disable=SC2010  # RPM filenames are safe; preserve original ls|grep pipeline
main_rpm=$(ls /rpms/centminmod-nginx*-[0-9]*.x86_64.rpm 2>/dev/null | grep -v debuginfo | grep -v module | head -1) || true
if [ -z "$main_rpm" ]; then
  echo "ERROR: base nginx RPM not found in /rpms"
  exit 1
fi
rpm -ivh --nodeps "$main_rpm" 2>&1 | tail -2
MOD_COUNT=0
if [ "$LOAD_MODULES" = "y" ]; then
  for rpm_file in /rpms/nginx-module-*.x86_64.rpm; do
    [ -f "$rpm_file" ] || continue
    if echo "$rpm_file" | grep -q debuginfo; then continue; fi
    rpm -ivh --nodeps "$rpm_file" 2>&1 | tail -1
  done
  MOD_COUNT=$(find /usr/local/nginx/modules -name "*.so" ! -name "*-debug.so" 2>/dev/null | wc -l) || true
fi
dnf -y install nghttp2 2>&1 | tail -3

# TLS cert
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
  -keyout /tmp/bench.key -out /tmp/bench.crt \
  -subj "/CN=localhost" 2>/dev/null || true

BENCH_CONF=/tmp/bench-nginx.conf
if [ "$LOAD_MODULES" = "y" ]; then
  echo "include /usr/local/nginx/conf/dynamic-modules.conf;" > "$BENCH_CONF"
  echo "Loading $MOD_COUNT modules via dynamic-modules.conf"
else
  : > "$BENCH_CONF"
fi
cat >> "$BENCH_CONF" << 'CONF'
worker_processes auto;
error_log /usr/local/nginx/logs/bench-error.log warn;
pid /tmp/bench-nginx.pid;
events { worker_connections 1024; }
http {
    include /usr/local/nginx/conf/mime.types;
    default_type application/octet-stream;
    access_log off;
    sendfile on;
    keepalive_timeout 65;
    server {
        listen 8443 ssl;
        http2 on;
        server_name localhost;
        ssl_certificate /tmp/bench.crt;
        ssl_certificate_key /tmp/bench.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_session_cache shared:SSL:1m;
        location / { root /usr/local/nginx/html; }
    }
}
CONF

/usr/local/sbin/nginx -t -c "$BENCH_CONF" 2>&1
/usr/local/sbin/nginx -c "$BENCH_CONF" || true
sleep 1
if ! kill -0 "$(cat /tmp/bench-nginx.pid 2>/dev/null)" 2>/dev/null; then
  echo "ERROR: nginx failed to start for scenario ${SCENARIO}"
  tail -30 /usr/local/nginx/logs/bench-error.log 2>/dev/null || true
  exit 1
fi

echo "=== Benchmark ${SCENARIO}: ${SCENARIO_LABEL} ==="
RESULT_FILE="/output/bench-${SCENARIO}.txt"
: > "$RESULT_FILE"
for THREADS in 1 2 4; do
  echo "--- threads=$THREADS ---"
  h2load -n 10000 -c 50 -m "${STREAMS}" -t "${THREADS}" https://127.0.0.1:8443/ > /dev/null 2>&1 || true
  for run in $(seq 1 "${RUNS}"); do
    OUT=$(h2load -n "${REQUESTS}" -c "${CLIENTS}" -m "${STREAMS}" -t "${THREADS}" https://127.0.0.1:8443/ 2>&1) || true
    REQS=$(echo "$OUT" | grep "finished in" | grep -oE "[0-9]+\.[0-9]+ req/s" | sed "s/ req\/s//") || true
    THROUGHPUT=$(echo "$OUT" | grep "finished in" | grep -oE "[0-9]+\.[0-9]+MB/s" | sed "s/MB\/s//") || true
    LAT_MEAN=$(echo "$OUT" | grep "time for request" | awk '{print $6}' | sed "s/ms//") || true
    LAT_MAX=$(echo "$OUT" | grep "time for request" | awk '{print $5}' | sed "s/ms//") || true
    if [ -z "$REQS" ]; then
      echo "ERROR: h2load produced no result for scenario ${SCENARIO} (threads=${THREADS} run=${run})"
      echo "$OUT" | tail -20
      exit 1
    fi
    echo "threads=${THREADS} run=${run} reqs=${REQS} throughput=${THROUGHPUT} latency_mean=${LAT_MEAN} latency_max=${LAT_MAX}" >> "$RESULT_FILE"
    echo "  t=${THREADS} run=${run}: ${REQS} req/s, ${LAT_MEAN}ms mean latency"
  done
done
/usr/local/sbin/nginx -s quit -c "$BENCH_CONF" 2>/dev/null || true
cat "$RESULT_FILE"
