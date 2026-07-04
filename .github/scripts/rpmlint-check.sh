#!/bin/bash
# rpmlint-check.sh — non-blocking rpmlint pass over built RPMs (Phase 5.1)
#
# Runs inside the rpmbuild:elN container with the built RPMs mounted at
# $RPMS_DIR (default /output). Uses the checked-in filter file
# rpm/SPECS/.rpmlintrc (accepted exceptions, documented there).
#
# Exit code = rpmlint's own exit code so the CI step (continue-on-error: true)
# shows findings without failing the build.
set -uo pipefail

RPMS_DIR="${RPMS_DIR:-/output}"
RCFILE="${RCFILE:-/home/builder/rpmbuild/SPECS/.rpmlintrc}"

echo "=== Installing rpmlint ==="
dnf install -y rpmlint 2>&1 | tail -2

shopt -s nullglob
rpms=("$RPMS_DIR"/*.rpm)
if [ ${#rpms[@]} -eq 0 ]; then
    echo "ERROR: no RPMs found in $RPMS_DIR"
    exit 1
fi
echo "=== rpmlint over ${#rpms[@]} RPMs (filters: $RCFILE) ==="

# rpmlint 2.x takes legacy filter files via -r; 1.x via -f
if rpmlint --version 2>/dev/null | grep -qE '(^| )[2-9]\.'; then
    RCOPT="-r"
else
    RCOPT="-f"
fi

rpmlint "$RCOPT" "$RCFILE" "${rpms[@]}"
RC=$?
echo ""
echo "=== rpmlint exit code: $RC (non-blocking) ==="
exit $RC
