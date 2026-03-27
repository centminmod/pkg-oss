# ngx-fancyindex

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGX_FANCYINDEX_URL := $(GITHUB)/aperezdc/ngx-fancyindex/archive/v$(NGX_FANCYINDEX_VERSION).tar.gz

PKGS += ngx-fancyindex

$(TARBALLS)/ngx-fancyindex-$(NGX_FANCYINDEX_VERSION).tar.gz:
	$(call download_pkg,$(NGX_FANCYINDEX_URL),ngx-fancyindex)

.sum-ngx-fancyindex: ngx-fancyindex-$(NGX_FANCYINDEX_VERSION).tar.gz

ngx-fancyindex: ngx-fancyindex-$(NGX_FANCYINDEX_VERSION).tar.gz .sum-ngx-fancyindex
	$(UNPACK)
	$(MOVE)

.ngx-fancyindex: ngx-fancyindex
	touch $@
