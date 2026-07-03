#!/bin/bash
# Local pre-flight validation before pushing — macOS-safe: every build-system
# check runs inside Docker (almalinux-based), nothing rpm/GNU-specific runs on
# the host. Catches the failure classes that historically needed
# debug-by-CI-push: sed-escaping bugs in make define blocks, spec-template
# generation errors, malformed patches, workflow/script lint errors.
#
# Usage: .github/scripts/preflight.sh [module]
#   module - optional: additionally smoke-build one module in the CI
#            rpmbuild:el9 image (e.g. "lua"), ~3-10 min + image build
#
# Or: cd rpm/SPECS && make preflight [MODULE=lua]
set -euo pipefail
cd "$(dirname "$0")/../.."

FAILED=0

echo "=== 1/4 sed-escape guard (unescaped && in make define blocks) ==="
# Inside define...endef blocks of rpm/SPECS/Makefile*, '&&' must be written
# '\&\&' — a bare '&' corrupts the sed substitution that injects the block
# into generated specs (broke all 26 modules once; see CLAUDE-patterns.md).
BAD=$(awk '
  /^define /{d=1; next}
  /^endef/{d=0}
  d && /&&/ && $0 !~ /\\&\\&/ {print FILENAME ":" FNR ": " $0}
' rpm/SPECS/Makefile rpm/SPECS/Makefile.module-* || true)
if [ -n "$BAD" ]; then
  echo "FAIL: unescaped && inside define blocks:"
  echo "$BAD"
  FAILED=1
else
  echo "PASS"
fi

echo ""
echo "=== 2/4 workflow + shell script lint (Docker) ==="
if docker info >/dev/null 2>&1; then
  # actionlint validates workflow YAML + expressions; inline-shellcheck of
  # run: blocks stays disabled until the Phase-3 script extraction lands.
  if docker run --rm -v "$(pwd):/repo" -w /repo rhysd/actionlint:latest -color -shellcheck=; then
    echo "PASS: actionlint"
  else
    echo "FAIL: actionlint"
    FAILED=1
  fi
  for f in .github/scripts/*.sh; do
    if docker run --rm -v "$(pwd)/.github/scripts:/mnt:ro" koalaman/shellcheck:stable "/mnt/$(basename "$f")"; then
      echo "PASS: shellcheck $f"
    else
      echo "FAIL: shellcheck $f"
      FAILED=1
    fi
  done
else
  echo "SKIP: Docker not running — start Docker Desktop for lint + spec checks"
  FAILED=1
fi

echo ""
echo "=== 3/4 patch hunk-format sanity ==="
PBAD=0
for p in contrib/src/*/*.patch; do
  [ -e "$p" ] || continue
  if ! grep -q "^@@ " "$p"; then
    echo "FAIL: no hunk header in $p"
    PBAD=1
  fi
done
if [ "$PBAD" -eq 0 ]; then echo "PASS"; else FAILED=1; fi

echo ""
echo "=== 4/4 spec-template generation dry-run (CI rpmbuild:el9 image) ==="
if docker info >/dev/null 2>&1; then
  docker build -q -f docker/Dockerfile.rpmbuild-el9 -t rpmbuild:el9 . >/dev/null
  if docker run --rm rpmbuild:el9 bash -c '
      set -e
      cd /home/builder/rpmbuild/SPECS
      make nginx.spec >/dev/null 2>&1
      make nginx-module-lua.spec nginx-module-njs.spec >/dev/null 2>&1
      for spec in nginx.spec nginx-module-lua.spec nginx-module-njs.spec; do
        if grep -q "%%[A-Z_]\{1,\}%%" "$spec"; then
          echo "FAIL: unsubstituted placeholders left in $spec:"
          grep -n "%%[A-Z_]\{1,\}%%" "$spec" | head -5
          exit 1
        fi
      done
      echo "PASS: nginx.spec + module specs generate cleanly, no stray %%VARS%%"
    '; then
    :
  else
    echo "FAIL: spec generation"
    FAILED=1
  fi
else
  echo "SKIP: Docker not running"
fi

if [ "$#" -ge 1 ] && [ -n "$1" ]; then
  MOD=$1
  echo ""
  echo "=== optional: smoke-build module-$MOD (CI rpmbuild:el9 image) ==="
  docker build -f docker/Dockerfile.rpmbuild-el9 -t rpmbuild:el9 .
  docker run --rm rpmbuild:el9 bash -c "
    set -e
    cd /home/builder/contrib && make .sum-nginx
    ln -sf /home/builder/contrib/tarballs/nginx-*.tar.gz /home/builder/rpmbuild/SOURCES/
    cd /home/builder/rpmbuild/SPECS && make module-$MOD
  "
  echo "PASS: module-$MOD smoke build"
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo "PREFLIGHT: FAILED — fix the issues above before pushing"
  exit 1
fi
echo "PREFLIGHT: OK"
