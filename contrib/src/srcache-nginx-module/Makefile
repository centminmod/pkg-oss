# srcache-nginx-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
SRCACHE_NGINX_MODULE_URL := $(GITHUB)/openresty/srcache-nginx-module/archive/v$(SRCACHE_NGINX_MODULE_VERSION).tar.gz

PKGS += srcache-nginx-module

$(TARBALLS)/srcache-nginx-module-$(SRCACHE_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(SRCACHE_NGINX_MODULE_URL),srcache-nginx-module)

.sum-srcache-nginx-module: srcache-nginx-module-$(SRCACHE_NGINX_MODULE_VERSION).tar.gz

srcache-nginx-module: srcache-nginx-module-$(SRCACHE_NGINX_MODULE_VERSION).tar.gz .sum-srcache-nginx-module
	$(UNPACK)
	$(MOVE)

.srcache-nginx-module: srcache-nginx-module
	touch $@
