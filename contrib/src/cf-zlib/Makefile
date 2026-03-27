# cloudflare zlib (SIMD-optimized zlib fork)

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
CF_ZLIB_URL := $(GITHUB)/cloudflare/zlib/archive/$(CF_ZLIB_COMMIT).tar.gz

PKGS += cf-zlib

$(TARBALLS)/zlib-$(CF_ZLIB_COMMIT).tar.gz:
	$(call download_pkg,$(CF_ZLIB_URL),cf-zlib)

.sum-cf-zlib: zlib-$(CF_ZLIB_COMMIT).tar.gz

cf-zlib: zlib-$(CF_ZLIB_COMMIT).tar.gz .sum-cf-zlib
	$(UNPACK)
	$(MOVE)

.cf-zlib: cf-zlib
	touch $@
