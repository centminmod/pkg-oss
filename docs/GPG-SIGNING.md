# GPG signing for rpm-nginx.centminmod.com

All RPMs (binary + source) and repository metadata (`repomd.xml`) published to
the R2 repo are GPG-signed by `publish-rpm-repo.yml`. Clients enforce
`gpgcheck=1` and `repo_gpgcheck=1`.

## One-time key setup

Generate a dedicated signing key (RSA 4096 — universally supported by rpm/dnf
on EL8/9/10; do NOT reuse a personal key):

```bash
export GNUPGHOME=$(mktemp -d)
gpg --batch --full-generate-key <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: Centmin Mod Nginx RPM Signing
Name-Email: rpm-signing@centminmod.com
Expire-Date: 2y
%commit
EOF
gpg --list-secret-keys --keyid-format long
```

Notes:

* `%no-protection` creates a passphrase-less key: signing in CI then needs no
  `GPG_PASSPHRASE` secret. If you prefer a passphrase, drop that line and set
  the `GPG_PASSPHRASE` secret as well — the signing scripts support both.
* For stronger hygiene, keep the primary key offline and export only a signing
  subkey (`gpg --export-secret-subkeys`); the scripts use whatever secret key
  material is in `GPG_PRIVATE_KEY`.

## GitHub secrets

```bash
gpg --armor --export-secret-keys <KEYID> | gh secret set GPG_PRIVATE_KEY --repo centminmod/pkg-oss
# optional, only if the key has a passphrase:
gh secret set GPG_PASSPHRASE --repo centminmod/pkg-oss
```

Then delete the temporary `GNUPGHOME` (after backing up the key material
somewhere offline/secure — e.g. a password manager or encrypted disk):

```bash
gpg --armor --export-secret-keys <KEYID> > OFFLINE-BACKUP-private.asc  # store securely, then:
rm -rf "$GNUPGHOME"
```

## Key bootstrap / trust path

The public key is served from the same domain as the RPMs
(`https://rpm-nginx.centminmod.com/RPM-GPG-KEY-centminmod-nginx`), so first
import is trust-on-first-use. To let users verify out-of-band, publish the key
**fingerprint** through at least one independent channel:

* this repository's README (github.com — different infrastructure), and
* centminmod.com (announcement/docs page).

Print the fingerprint with `gpg --fingerprint <KEYID>`.

## What the pipeline does (publish-rpm-repo.yml)

1. `.github/scripts/sign-rpms.sh` — signs every staged RPM/SRPM
   (`rpmsign --addsign`) **before** `createrepo_c` runs (signing changes RPM
   checksums), verifies each with `rpm --checksig`, exports the public key.
2. `createrepo_c` generates repodata from the signed RPMs.
3. `.github/scripts/sign-repomd.sh` — detach-signs `repodata/repomd.xml`
   (→ `repomd.xml.asc`, verified before upload).
4. Upload order: RPMs → metadata blobs → `repomd.xml.asc` → `repomd.xml`
   (entry point last), then public key to the bucket root, then CDN purge.

If `GPG_PRIVATE_KEY` is not configured, the publish workflow fails fast with
an explicit error — unsigned publishes are no longer possible.

## Migration note

Repos published before signing have no `repomd.xml.asc` and unsigned RPMs.
`test-rpm-repo.yml` auto-detects (checks for `repomd.xml.asc`) and only
enforces gpgcheck on signed repos. Republish every variant × EL combination
once to complete the migration; after that the detection always finds
signatures.

## Rotation / revocation runbook

Rotate (planned, e.g. before expiry):

1. Generate a new key (above), extend expiry or create fresh.
2. Update `GPG_PRIVATE_KEY` secret.
3. Republish all variants (re-signs RPMs + metadata, replaces the served
   public key).
4. Update fingerprint in README + centminmod.com. Users with the old key
   imported will be prompted by dnf to accept the new key.

Revoke (compromise):

1. Generate a revocation certificate from the offline backup:
   `gpg --gen-revoke <KEYID>` and publish it in the same channels as the
   fingerprint; state the compromise date.
2. Follow the rotation steps with a brand-new key.
3. Users should `rpm -e gpg-pubkey-<oldkeyid>` and import the new key.
