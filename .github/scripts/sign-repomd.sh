#!/bin/bash
# Detach-sign repodata/repomd.xml for one or more repo directories
# (enables repo_gpgcheck=1 on the client side).
#
# Runs INSIDE an almalinux:9 container (invoked by publish-rpm-repo.yml).
# Arguments: one or more repo root directories (each containing repodata/).
# Environment:
#   GPG_PRIVATE_KEY - ASCII-armored private signing key (required)
#   GPG_PASSPHRASE  - key passphrase (optional)
set -euo pipefail

[ -n "${GPG_PRIVATE_KEY:-}" ] || { echo "ERROR: GPG_PRIVATE_KEY not set"; exit 1; }
[ "$#" -ge 1 ] || { echo "usage: sign-repomd.sh <repo-dir>..."; exit 1; }

dnf -y -q install gnupg2 >/dev/null

export GNUPGHOME
GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"

printf '%s\n' "$GPG_PRIVATE_KEY" | gpg --batch --quiet --import

PP_ARGS=""
if [ -n "${GPG_PASSPHRASE:-}" ]; then
  PP_FILE=$(mktemp)
  printf '%s' "$GPG_PASSPHRASE" > "$PP_FILE"
  PP_ARGS="--pinentry-mode loopback --passphrase-file $PP_FILE"
fi

for dir in "$@"; do
  REPOMD="$dir/repodata/repomd.xml"
  [ -f "$REPOMD" ] || { echo "ERROR: $REPOMD missing"; exit 1; }
  # shellcheck disable=SC2086
  gpg --batch --yes $PP_ARGS --detach-sign --armor "$REPOMD"
  gpg --verify "$REPOMD.asc" "$REPOMD"
  echo "Signed: $REPOMD.asc"
done

echo "DONE: repomd.xml signed for $# repo dir(s)"
