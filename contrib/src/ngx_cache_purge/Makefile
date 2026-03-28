# ngx_cache_purge

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGX_CACHE_PURGE_URL := $(GITHUB)/nginx-modules/ngx_cache_purge/archive/$(NGX_CACHE_PURGE_VERSION).tar.gz

PKGS += ngx_cache_purge

$(TARBALLS)/ngx_cache_purge-$(NGX_CACHE_PURGE_VERSION).tar.gz:
	$(call download_pkg,$(NGX_CACHE_PURGE_URL),ngx_cache_purge)

.sum-ngx_cache_purge: ngx_cache_purge-$(NGX_CACHE_PURGE_VERSION).tar.gz

ngx_cache_purge: ngx_cache_purge-$(NGX_CACHE_PURGE_VERSION).tar.gz .sum-ngx_cache_purge
	$(UNPACK)
	$(MOVE)

.ngx_cache_purge: ngx_cache_purge
	touch $@
