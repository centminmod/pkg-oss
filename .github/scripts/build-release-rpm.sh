#!/bin/bash
# Build and sign the centminmod-nginx-release noarch RPM (repo config +
# GPG public key, epel-release pattern).
#
# Runs INSIDE an almalinux:9 container (invoked by publish-rpm-repo.yml,
# stable variant only). Expected mounts:
#   /keys   - contains RPM-GPG-KEY-centminmod-nginx; receives the built RPM
#   /repo   - stable repo staging dir (RPM is staged here for repodata)
#   /specs  - rpm/SPECS dir (read-only; provides the spec file)
# Environment:
#   GPG_PRIVATE_KEY - ASCII-armored private signing key (required)
#   GPG_PASSPHRASE  - key passphrase (optional)
set -euo pipefail

[ -n "${GPG_PRIVATE_KEY:-}" ] || { echo "ERROR: GPG_PRIVATE_KEY not set"; exit 1; }
[ -f /keys/RPM-GPG-KEY-centminmod-nginx ] || { echo "ERROR: public key missing from /keys"; exit 1; }

dnf -y -q install rpm-build rpm-sign gnupg2 >/dev/null

TOP=$(mktemp -d)
mkdir -p "$TOP"/{SOURCES,SPECS,RPMS,BUILD,SRPMS}

cat > "$TOP/SOURCES/centminmod-nginx.repo" <<'EOF'
[centminmod-nginx]
name=Centmin Mod Nginx
baseurl=https://rpm-nginx.centminmod.com/stable/el/$releasever/$basearch/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centminmod-nginx
metadata_expire=6h
EOF
cp /keys/RPM-GPG-KEY-centminmod-nginx "$TOP/SOURCES/"
cp /specs/centminmod-nginx-release.spec "$TOP/SPECS/"

echo "=== Building release RPM ==="
rpmbuild --define "_topdir $TOP" -bb "$TOP/SPECS/centminmod-nginx-release.spec"

RPM=$(find "$TOP/RPMS" -name 'centminmod-nginx-release-*.noarch.rpm' | head -1)
[ -n "$RPM" ] || { echo "ERROR: release RPM not built"; exit 1; }

echo "=== Signing release RPM ==="
export GNUPGHOME
GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"
printf '%s\n' "$GPG_PRIVATE_KEY" | gpg --batch --quiet --import
KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')
[ -n "$KEYID" ] || { echo "ERROR: no secret key found after import"; exit 1; }

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

rpmsign --addsign "$RPM"
rpm --import /keys/RPM-GPG-KEY-centminmod-nginx
rpm --checksig "$RPM" | grep -q "signatures OK" || {
  echo "ERROR: release RPM signature verification failed"
  exit 1
}

cp "$RPM" /repo/
cp "$RPM" /keys/centminmod-nginx-release.noarch.rpm
echo "DONE: $(basename "$RPM") built, signed, and staged"
