#!/usr/bin/env bash
# Phase 6.1: upstream version watch — compares contrib/src/*/version pins
# against upstream releases/tags/commits and emits a markdown report.
#
# Tokenless by design: uses `git ls-remote` (no GitHub API rate limits) and
# version.nginx.com. For the big-4 sources (nginx, njs, openssl, awslc) a
# detected bump also downloads the new tarball and prints a ready-to-append
# SHA512SUMS line (the "SHA512SUMS preflight").
#
# Exit codes: 0 = everything current, 1 = at least one bump found,
#             2 = one or more upstream checks errored (network etc.)
#
# Env: WATCH_REPORT — markdown report path (default: version-watch-report.md)
#
# Deliberately NOT watched:
#   - otel-only build deps (abseil-cpp, grpc, protobuf, opentelemetry-*):
#     the otel module is deferred and not in BASE_MODULES
#   - xslscript, nginx-tests: build/test tooling, not shipped code
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1   # repo root
REPORT="${WATCH_REPORT:-version-watch-report.md}"

# dir|method|source|filter|strip
#   method=nginxcom  source=nginx|njs (version.nginx.com/<source>/mainline)
#   method=tag       source=owner/repo, filter=grep -E over tag names,
#                    strip=sed -E expression normalizing tag -> bare version
#   method=commit    source=owner/repo, filter=ref to resolve (HEAD or
#                    refs/heads/<branch>), strip unused
WATCHLIST='
nginx|nginxcom|nginx||
njs|nginxcom|njs||
openssl|tag|openssl/openssl|^openssl-3\.5\.[0-9]+$|s/^openssl-//
awslc|tag|aws/aws-lc|^v[0-9][0-9.]*$|s/^v//
cf-zlib|commit|cloudflare/zlib|refs/heads/gcc.amd64|
lua-nginx-module|tag|openresty/lua-nginx-module|^v[0-9][0-9.]*$|s/^v//
stream-lua-nginx-module|tag|openresty/stream-lua-nginx-module|^v[0-9][0-9.]*$|s/^v//
lua-resty-core|tag|openresty/lua-resty-core|^v[0-9][0-9.]*$|s/^v//
lua-resty-lrucache|tag|openresty/lua-resty-lrucache|^v[0-9][0-9.]*$|s/^v//
luajit2|tag|openresty/luajit2|^v2\.[0-9]+-[0-9]{8}$|s/^v//
echo-nginx-module|tag|openresty/echo-nginx-module|^v[0-9][0-9.]*$|s/^v//
encrypted-session-nginx-module|tag|openresty/encrypted-session-nginx-module|^v[0-9][0-9.]*$|s/^v//
memc-nginx-module|tag|openresty/memc-nginx-module|^v[0-9][0-9.]*$|s/^v//
redis2-nginx-module|tag|openresty/redis2-nginx-module|^v[0-9][0-9.]*$|s/^v//
set-misc-nginx-module|tag|openresty/set-misc-nginx-module|^v[0-9][0-9.]*$|s/^v//
srcache-nginx-module|tag|openresty/srcache-nginx-module|^v[0-9][0-9.]*$|s/^v//
ngx_devel_kit|tag|vision5/ngx_devel_kit|^v[0-9][0-9.]*$|s/^v//
ngx_brotli|tag|google/ngx_brotli|^v[0-9][0-9.]*(rc)?$|s/^v//;s/rc$//
ngx_cache_purge|tag|nginx-modules/ngx_cache_purge|^[0-9][0-9.]*$|
ngx_http_geoip2_module|tag|leev/ngx_http_geoip2_module|^[0-9][0-9.]*$|
ngx_http_redis|tag|centminmod/ngx_http_redis|^[0-9][0-9.]*-cmm$|
nginx-module-vts|tag|vozlt/nginx-module-vts|^v[0-9][0-9.]*$|s/^v//
nginx-rtmp-module|tag|arut/nginx-rtmp-module|^v[0-9][0-9.]*$|s/^v//
nginx-dav-ext-module|tag|arut/nginx-dav-ext-module|^v[0-9][0-9.]*$|s/^v//
nginx-accesskey|tag|Martchus/nginx-accesskey|^v[0-9][0-9.]*$|s/^v//
nginx-ssl-fingerprint|tag|centminmod/nginx-ssl-fingerprint|^v[0-9][0-9.]*$|s/^v//
nginx-fips-check-module|tag|ogarrett/nginx-fips-check-module|^v[0-9][0-9.]*$|s/^v//
nginx-acme|tag|nginx/nginx-acme|^v[0-9][0-9.]*$|s/^v//
nginx-http-concat|tag|alibaba/nginx-http-concat|^[0-9][0-9.]*$|
nginx-length-hiding-filter-module|tag|nulab/nginx-length-hiding-filter-module|^[0-9][0-9.]*$|
nginx_upstream_check_module|tag|yaoweibin/nginx_upstream_check_module|^v[0-9][0-9.]*$|s/^v//
ngx-fancyindex|tag|aperezdc/ngx-fancyindex|^v[0-9][0-9.]*$|s/^v//
zstd-nginx-module|tag|tokers/zstd-nginx-module|^[0-9][0-9.]*$|
passenger|tag|phusion/passenger|^release-[0-9][0-9.]*$|s/^release-//
headers-more-nginx-module|commit|openresty/headers-more-nginx-module|HEAD|
ngx_http_substitutions_filter_module|commit|yaoweibin/ngx_http_substitutions_filter_module|HEAD|
quickjs|commit|bellard/quickjs|HEAD|
spnego-http-auth-nginx-module|commit|stnoonan/spnego-http-auth-nginx-module|HEAD|
nginx-sticky-module-ng|commit|Refinitiv/nginx-sticky-module-ng|HEAD|
testcookie-nginx-module|commit|kyprizel/testcookie-nginx-module|HEAD|
nginx-http-rdns|commit|flant/nginx-http-rdns|HEAD|
nginx-otel|commit|nginxinc/nginx-otel|HEAD|
'

# Current pin from contrib/src/<dir>/version: GITHASH/COMMIT for method=commit,
# else the first *_VERSION value.
current_pin() {
  local dir=$1 method=$2 file="contrib/src/$1/version"
  [ -f "$file" ] || { echo ""; return; }
  if [ "$method" = "commit" ]; then
    sed -nE 's/^[A-Z0-9_]*(GITHASH|COMMIT) := (.*)$/\2/p' "$file" | head -1
  else
    sed -nE 's/^[A-Z0-9_]*VERSION := (.*)$/\1/p' "$file" | head -1
  fi
}

upstream_version() {
  local method=$1 source=$2 filter=$3 strip=$4
  case "$method" in
    nginxcom)
      local raw
      raw=$(curl -fs --max-time 30 "https://version.nginx.com/${source}/mainline") || return 1
      if [ "$source" = "njs" ]; then
        # format: <nginx>+<njs>-<rel>, e.g. 1.29.7+0.9.6-1
        echo "$raw" | cut -d- -f1 | cut -d+ -f2
      else
        echo "$raw" | cut -d- -f1
      fi
      ;;
    tag)
      local tags
      tags=$(git ls-remote --tags --refs "https://github.com/${source}" 2>/dev/null \
        | sed 's|.*refs/tags/||' | grep -E "$filter") || return 1
      if [ -n "$strip" ]; then tags=$(echo "$tags" | sed -E "$strip"); fi
      echo "$tags" | sort -V | tail -1
      ;;
    commit)
      git ls-remote "https://github.com/${source}" "$filter" 2>/dev/null | head -1 | cut -f1
      ;;
  esac
}

# SHA512SUMS preflight for the big 4 — mirrors the local tarball names the
# contrib Makefiles use, so the line can be appended to SHA512SUMS verbatim.
sha512_line() {
  local dir=$1 ver=$2 url="" name=""
  case "$dir" in
    nginx)   url="https://nginx.org/download/nginx-${ver}.tar.gz"; name="nginx-${ver}.tar.gz" ;;
    njs)     url="https://github.com/nginx/njs/archive/${ver}.tar.gz"; name="njs-${ver}.tar.gz" ;;
    openssl) url="https://github.com/openssl/openssl/releases/download/openssl-${ver}/openssl-${ver}.tar.gz"; name="openssl-${ver}.tar.gz" ;;
    awslc)   url="https://github.com/aws/aws-lc/archive/refs/tags/v${ver}.tar.gz"; name="aws-lc-${ver}.tar.gz" ;;
    *) return 0 ;;
  esac
  local tmp; tmp=$(mktemp)
  if curl -fsL --max-time 300 -o "$tmp" "$url"; then
    local sum; sum=$(sha512sum "$tmp" | cut -d' ' -f1)
    echo "${sum}  ${name}"
  else
    echo "(download failed: ${url})"
  fi
  rm -f "$tmp"
}

BUMPS=0; ERRORS=0; CURRENT=0
BUMP_ROWS=""; SHA_BLOCKS=""

echo "=== Upstream version watch ==="
while IFS='|' read -r dir method source filter strip; do
  [ -n "$dir" ] || continue
  cur=$(current_pin "$dir" "$method")
  if [ -z "$cur" ]; then
    echo "ERROR $dir: no pin found in contrib/src/$dir/version"
    ERRORS=$((ERRORS+1)); continue
  fi
  up=$(upstream_version "$method" "$source" "$filter" "$strip")
  if [ -z "$up" ]; then
    echo "ERROR $dir: upstream check failed (${method} ${source})"
    ERRORS=$((ERRORS+1)); continue
  fi
  if [ "$method" = "commit" ]; then
    if [ "$cur" = "$up" ]; then
      printf "OK    %-40s %s\n" "$dir" "${cur:0:12}"
      CURRENT=$((CURRENT+1))
    else
      printf "BUMP  %-40s %s -> %s\n" "$dir" "${cur:0:12}" "${up:0:12}"
      BUMPS=$((BUMPS+1))
      BUMP_ROWS="${BUMP_ROWS}| \`${dir}\` | \`${cur:0:12}\` | \`${up:0:12}\` | [${source}](https://github.com/${source}/compare/${cur}...${up}) |\n"
    fi
  else
    # bump only when upstream sorts strictly newer (ignore yanked/older tags)
    if [ "$cur" = "$up" ] || [ "$(printf '%s\n%s\n' "$cur" "$up" | sort -V | tail -1)" = "$cur" ]; then
      printf "OK    %-40s %s\n" "$dir" "$cur"
      CURRENT=$((CURRENT+1))
    else
      printf "BUMP  %-40s %s -> %s\n" "$dir" "$cur" "$up"
      BUMPS=$((BUMPS+1))
      link="version.nginx.com"
      [ "$method" = "tag" ] && link="[${source}](https://github.com/${source}/releases)"
      BUMP_ROWS="${BUMP_ROWS}| \`${dir}\` | ${cur} | **${up}** | ${link} |\n"
      case "$dir" in
        nginx|njs|openssl|awslc)
          echo "      downloading new tarball for SHA512SUMS preflight..."
          line=$(sha512_line "$dir" "$up")
          SHA_BLOCKS="${SHA_BLOCKS}Append to \`contrib/src/${dir}/SHA512SUMS\`:\n\`\`\`\n${line}\n\`\`\`\n"
          ;;
      esac
    fi
  fi
done <<EOF
$(echo "$WATCHLIST" | grep -v '^[[:space:]]*$')
EOF

echo ""
echo "=== Summary: ${CURRENT} current, ${BUMPS} bumps, ${ERRORS} errors ==="

{
  echo "## Upstream version watch — $(date -u '+%Y-%m-%d')"
  echo ""
  echo "${CURRENT} current, **${BUMPS} bumps**, ${ERRORS} check errors."
  if [ "$BUMPS" -gt 0 ]; then
    echo ""
    echo "| Component | Pinned | Upstream | Source |"
    echo "|---|---|---|---|"
    printf '%b' "$BUMP_ROWS"
    if [ -n "$SHA_BLOCKS" ]; then
      echo ""
      echo "### SHA512SUMS preflight"
      printf '%b' "$SHA_BLOCKS"
    fi
    echo ""
    echo "Bump procedure: update \`contrib/src/<name>/version\` (+ SHA512SUMS line),"
    echo "add a \`docs/*.xml\` changelog entry (\`make release\` / \`make release-njs\`"
    echo "for nginx/njs), then run \`make preflight\` and a targeted CI build."
  fi
} > "$REPORT"
echo "Report written to ${REPORT}"

[ "$ERRORS" -gt 0 ] && exit 2
[ "$BUMPS" -gt 0 ] && exit 1
exit 0
