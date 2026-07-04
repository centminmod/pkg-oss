#!/bin/bash
# Sign all staged RPMs with the repository GPG signing key and export the
# public key for repo consumers.
#
# Runs INSIDE an almalinux:9 container (invoked by publish-rpm-repo.yml).
# Expected mounts:
#   /repo   - binary RPM staging dir (required)
#   /srpms  - source RPM staging dir (optional)
#   /keys   - output dir for the exported public key (required)
# Environment:
#   GPG_PRIVATE_KEY - ASCII-armored private signing key (required)
#   GPG_PASSPHRASE  - key passphrase (optional; omit for a passphrase-less
#                     dedicated signing subkey)
set -euo pipefail

[ -n "${GPG_PRIVATE_KEY:-}" ] || { echo "ERROR: GPG_PRIVATE_KEY not set"; exit 1; }

echo "=== Installing signing tools ==="
dnf -y -q install rpm-sign gnupg2 >/dev/null

export GNUPGHOME
GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"

echo "=== Importing signing key ==="
printf '%s\n' "$GPG_PRIVATE_KEY" | gpg --batch --quiet --import
KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')
FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
[ -n "$KEYID" ] || { echo "ERROR: no secret key found after import"; exit 1; }
echo "Signing key: $KEYID"
echo "Fingerprint: $FPR"

PP_ARGS=""
if [ -n "${GPG_PASSPHRASE:-}" ]; then
  PP_FILE=$(mktemp)
  printf '%s' "$GPG_PASSPHRASE" > "$PP_FILE"
  PP_ARGS="--pinentry-mode loopback --passphrase-file $PP_FILE"
fi

cat > "$HOME/.rpmmacros" <<EOF
%_signature gpg
%_gpg_name $KEYID
%_gpg_sign_cmd_extra_args --batch $PP_ARGS
EOF

echo "=== Exporting public key ==="
gpg --armor --export "$KEYID" > /keys/RPM-GPG-KEY-centminmod-nginx
rpm --import /keys/RPM-GPG-KEY-centminmod-nginx

sign_dir() {
  local dir=$1
  if ! ls "$dir"/*.rpm >/dev/null 2>&1; then
    echo "No RPMs in $dir — skipping"
    return 0
  fi
  echo "=== Signing RPMs in $dir ==="
  rpmsign --addsign "$dir"/*.rpm
  local bad=0 f
  for f in "$dir"/*.rpm; do
    if rpm --checksig "$f" | grep -q "signatures OK"; then
      echo "PASS: $(basename "$f")"
    else
      echo "FAIL: $(basename "$f") -> $(rpm --checksig "$f")"
      bad=$((bad+1))
    fi
  done
  if [ "$bad" -ne 0 ]; then
    echo "ERROR: $bad RPM(s) failed signature verification"
    exit 1
  fi
}

sign_dir /repo
[ -d /srpms ] && sign_dir /srpms

echo "DONE: all RPMs signed and verified (key $KEYID)"
