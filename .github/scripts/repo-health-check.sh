#!/bin/bash
# Scheduled health check of the published R2 RPM repos (Phase 4.5).
# For every variant x EL combo: a repo that is not published at all is a
# WARN (publish gaps are an operational choice); a repo that IS published
# must pass all checks or the script exits 1:
#   1. repomd.xml fetches from the CDN
#   2. repomd.xml references primary/filelists/other metadata
#   3. every referenced metadata blob is fetchable
#   4. repomd.xml.asc verifies against the published GPG key (WARN if the
#      repo predates the signing pipeline and has no .asc)
#   5. the first package in primary.xml.gz is fetchable
set -euo pipefail

DOMAIN="https://rpm-nginx.centminmod.com"
VARIANTS="stable awslc openssl optimized optimized-v4 awslc-optimized awslc-optimized-v4 bolt"
ELS="8 9 10"

FAIL=0
WARN=0
CHECKED=0
SUMMARY=""

note() { SUMMARY="${SUMMARY}\n$1"; echo "$1"; }

# One GPG home for the run; import the published key once
export GNUPGHOME
GNUPGHOME=$(mktemp -d)
if curl -sf "${DOMAIN}/RPM-GPG-KEY-centminmod-nginx" -o /tmp/repo-key.asc; then
  gpg --quiet --import /tmp/repo-key.asc
  KEY_OK=1
else
  note "FAIL: GPG public key not fetchable from ${DOMAIN}/RPM-GPG-KEY-centminmod-nginx"
  KEY_OK=0
  FAIL=$((FAIL+1))
fi

for VARIANT in $VARIANTS; do
  for EL in $ELS; do
    # bolt is EL9-only
    if [ "$VARIANT" = "bolt" ] && [ "$EL" != "9" ]; then continue; fi

    BASE="${DOMAIN}/${VARIANT}/el/${EL}/x86_64"
    NAME="${VARIANT}/el${EL}"

    if ! curl -sf "${BASE}/repodata/repomd.xml" -o /tmp/repomd.xml; then
      note "WARN: ${NAME} not published (repomd.xml 404) — skipping"
      WARN=$((WARN+1))
      continue
    fi
    CHECKED=$((CHECKED+1))
    OK=1

    # Metadata types
    for mtype in primary filelists other; do
      if ! grep -q "type=\"$mtype\"" /tmp/repomd.xml; then
        note "FAIL: ${NAME} repomd.xml missing ${mtype} metadata reference"
        OK=0
      fi
    done

    # Every referenced blob fetchable
    HREFS=$(grep -o 'href="repodata/[^"]*"' /tmp/repomd.xml | sed 's/href="//;s/"//')
    for h in $HREFS; do
      if ! curl -sfo /dev/null -I "${BASE}/${h}"; then
        note "FAIL: ${NAME} referenced blob unreachable: ${h}"
        OK=0
      fi
    done

    # Signature
    if curl -sf "${BASE}/repodata/repomd.xml.asc" -o /tmp/repomd.xml.asc; then
      if [ "$KEY_OK" = "1" ]; then
        if gpg --quiet --verify /tmp/repomd.xml.asc /tmp/repomd.xml 2>/dev/null; then
          : # signature good
        else
          note "FAIL: ${NAME} repomd.xml.asc does NOT verify against the published key"
          OK=0
        fi
      fi
    else
      note "WARN: ${NAME} unsigned (no repomd.xml.asc — pre-signing publish)"
      WARN=$((WARN+1))
    fi

    # First package in primary.xml.gz fetchable
    PRIMARY=$(echo "$HREFS" | grep -m1 "primary.xml" || true)
    if [ -n "$PRIMARY" ]; then
      PKG_HREF=$(curl -sf "${BASE}/${PRIMARY}" | gunzip 2>/dev/null \
        | grep -o '<location href="[^"]*"' | head -1 | sed 's/<location href="//;s/"//') || true
      if [ -n "$PKG_HREF" ]; then
        if ! curl -sfo /dev/null -I "${BASE}/${PKG_HREF}"; then
          note "FAIL: ${NAME} sample RPM unreachable: ${PKG_HREF}"
          OK=0
        fi
      else
        note "FAIL: ${NAME} could not extract a package href from primary.xml.gz"
        OK=0
      fi
    fi

    if [ "$OK" = "1" ]; then
      note "PASS: ${NAME}"
    else
      FAIL=$((FAIL+1))
    fi
  done
done

# --- Phase 6.3: R2 storage usage (billing proxy) ---
# Runs only when the workflow passes R2 credentials; skipped otherwise so the
# script stays runnable against the public CDN alone. Thresholds in GiB are
# env-tunable; R2 free tier is 10 GB-month, so warn/alert before it is hit.
if [ -n "${R2_ENDPOINT:-}" ] && [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
  WARN_GB=${R2_STORAGE_WARN_GB:-7}
  FAIL_GB=${R2_STORAGE_FAIL_GB:-9}
  BUCKET=${R2_BUCKET:-rpm-nginx}
  echo ""
  if TOTALS=$(aws s3 ls "s3://${BUCKET}" --recursive --summarize \
        --endpoint-url "${R2_ENDPOINT}" | tail -2); then
    BYTES=$(echo "$TOTALS" | awk '/Total Size:/ {print $3}')
    OBJECTS=$(echo "$TOTALS" | awk '/Total Objects:/ {print $2}')
    GIB=$(awk -v b="$BYTES" 'BEGIN{printf "%.2f", b/1024/1024/1024}')
    echo "R2 storage: ${OBJECTS} objects, ${GIB} GiB in bucket ${BUCKET} (warn ${WARN_GB}, fail ${FAIL_GB})"
    if awk -v a="$GIB" -v b="$FAIL_GB" 'BEGIN{exit !(a>=b)}'; then
      note "FAIL: R2 storage ${GIB} GiB >= ${FAIL_GB} GiB (billing risk — prune old NEVRAs via prune-rpm-repo.yml)"
      FAIL=$((FAIL+1))
    elif awk -v a="$GIB" -v b="$WARN_GB" 'BEGIN{exit !(a>=b)}'; then
      note "WARN: R2 storage ${GIB} GiB >= ${WARN_GB} GiB (approaching the 10 GB free tier)"
      WARN=$((WARN+1))
    fi
  else
    note "FAIL: R2 storage check errored (aws s3 ls on bucket ${BUCKET})"
    FAIL=$((FAIL+1))
  fi
fi

echo ""
echo "=========================================="
echo "Repo health: ${CHECKED} published repos checked, ${FAIL} failing, ${WARN} warnings"
echo "=========================================="
echo -e "$SUMMARY" | grep -E "^(FAIL|WARN)" || echo "All published repos healthy"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
