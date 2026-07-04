#!/usr/bin/env bash
# Phase 6.2: generate a CycloneDX 1.6 SBOM for one published variant/EL repo.
#
# Source components come from the attest-* files the build exports into the
# RPM artifact (one "name version sha512" line per contrib dep, produced by
# contrib/attestation.mak + build-module-rpms.sh). Package components are the
# staged (signed) RPMs themselves, with SHA-256 digests and pkg:rpm purls.
#
# Env:
#   ATTEST_DIR — directory containing attest-* files (default: downloaded-rpms)
#   RPM_DIR    — staged binary RPM directory (required)
#   SRPM_DIR   — staged source RPM directory (optional)
#   VARIANT    — repo variant name (required)
#   EL_VERSION — EL major version (required)
#   OUTPUT     — output path (default: sbom.cdx.json)
set -euo pipefail

ATTEST_DIR="${ATTEST_DIR:-downloaded-rpms}"
RPM_DIR="${RPM_DIR:?RPM_DIR is required}"
SRPM_DIR="${SRPM_DIR:-}"
VARIANT="${VARIANT:?VARIANT is required}"
EL_VERSION="${EL_VERSION:?EL_VERSION is required}"
OUTPUT="${OUTPUT:-sbom.cdx.json}"

COMPONENTS=$(mktemp)
trap 'rm -f "$COMPONENTS"' EXIT

# --- Source components (deduped across all attest files) ---
SRC_COUNT=0
if ls "$ATTEST_DIR"/attest-* >/dev/null 2>&1; then
  while read -r name version sha512; do
    if [ -z "$name" ] || [ -z "$version" ]; then continue; fi
    jq -n --arg n "$name" --arg v "$version" --arg h "${sha512:-}" \
      '{type: "library", name: $n, version: $v, scope: "required"}
       + (if $h != "" then {hashes: [{alg: "SHA-512", content: $h}]} else {} end)' \
      >> "$COMPONENTS"
    SRC_COUNT=$((SRC_COUNT+1))
  done < <(cat "$ATTEST_DIR"/attest-* | awk 'NF>=2' | sort -u)
else
  echo "WARNING: no attest-* files in ${ATTEST_DIR} (older build run?) — SBOM will list RPMs only"
fi

# --- RPM package components ---
rpm_component() {
  local f=$1 arch=$2
  local base name_ver_rel rel ver name sha256
  base=$(basename "$f" .rpm)          # <name>-<ver>-<rel>.<arch>
  base=${base%."$arch"}               # <name>-<ver>-<rel>
  rel=${base##*-}
  name_ver_rel=${base%-*}             # <name>-<ver>
  ver=${name_ver_rel##*-}
  name=${name_ver_rel%-*}
  sha256=$(sha256sum "$f" | cut -d' ' -f1)
  jq -n --arg n "$name" --arg v "${ver}-${rel}" --arg h "$sha256" --arg a "$arch" \
    '{type: "application", name: $n, version: $v,
      purl: ("pkg:rpm/centminmod/" + $n + "@" + $v + "?arch=" + $a),
      hashes: [{alg: "SHA-256", content: $h}]}'
}

RPM_COUNT=0
for f in "$RPM_DIR"/*.x86_64.rpm "$RPM_DIR"/*.noarch.rpm; do
  [ -f "$f" ] || continue
  case "$f" in *.noarch.rpm) arch=noarch ;; *) arch=x86_64 ;; esac
  rpm_component "$f" "$arch" >> "$COMPONENTS"
  RPM_COUNT=$((RPM_COUNT+1))
done
if [ -n "$SRPM_DIR" ] && ls "$SRPM_DIR"/*.src.rpm >/dev/null 2>&1; then
  for f in "$SRPM_DIR"/*.src.rpm; do
    rpm_component "$f" "src" >> "$COMPONENTS"
    RPM_COUNT=$((RPM_COUNT+1))
  done
fi

if [ "$RPM_COUNT" -eq 0 ]; then
  echo "ERROR: no RPMs found in ${RPM_DIR}"
  exit 1
fi

UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen | tr 'A-F' 'a-f')
NGINX_VERSION=$(awk '$1 == "nginx" {print $2; exit}' "$ATTEST_DIR"/attest-base 2>/dev/null || true)

jq -s \
  --arg uuid "$UUID" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg variant "$VARIANT" \
  --arg el "$EL_VERSION" \
  --arg nginx_ver "${NGINX_VERSION:-unknown}" \
  '{bomFormat: "CycloneDX",
    specVersion: "1.6",
    serialNumber: ("urn:uuid:" + $uuid),
    version: 1,
    metadata: {
      timestamp: $ts,
      component: {
        type: "application",
        name: ("centminmod-nginx-" + $variant + "-el" + $el),
        version: $nginx_ver,
        description: ("Centmin Mod Nginx RPM repository: variant " + $variant + ", EL" + $el)
      },
      supplier: {name: "Centmin Mod", url: ["https://rpm-nginx.centminmod.com"]}
    },
    components: .}' "$COMPONENTS" > "$OUTPUT"

echo "SBOM written to ${OUTPUT}: ${SRC_COUNT} source components, ${RPM_COUNT} RPM components"
jq -e '.components | length > 0' "$OUTPUT" >/dev/null
