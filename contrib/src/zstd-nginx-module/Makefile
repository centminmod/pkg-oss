# zstd-nginx-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
ZSTD_NGINX_MODULE_URL := $(GITHUB)/tokers/zstd-nginx-module/archive/$(ZSTD_NGINX_MODULE_VERSION).tar.gz

PKGS += zstd-nginx-module

$(TARBALLS)/zstd-nginx-module-$(ZSTD_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(ZSTD_NGINX_MODULE_URL),zstd-nginx-module)

.sum-zstd-nginx-module: zstd-nginx-module-$(ZSTD_NGINX_MODULE_VERSION).tar.gz

zstd-nginx-module: zstd-nginx-module-$(ZSTD_NGINX_MODULE_VERSION).tar.gz .sum-zstd-nginx-module
	$(UNPACK)
	$(MOVE)

.zstd-nginx-module: zstd-nginx-module
	touch $@
