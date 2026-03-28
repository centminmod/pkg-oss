# redis2-nginx-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
REDIS2_NGINX_MODULE_URL := $(GITHUB)/openresty/redis2-nginx-module/archive/v$(REDIS2_NGINX_MODULE_VERSION).tar.gz

PKGS += redis2-nginx-module

$(TARBALLS)/redis2-nginx-module-$(REDIS2_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(REDIS2_NGINX_MODULE_URL),redis2-nginx-module)

.sum-redis2-nginx-module: redis2-nginx-module-$(REDIS2_NGINX_MODULE_VERSION).tar.gz

redis2-nginx-module: redis2-nginx-module-$(REDIS2_NGINX_MODULE_VERSION).tar.gz .sum-redis2-nginx-module
	$(UNPACK)
	$(MOVE)

.redis2-nginx-module: redis2-nginx-module
	touch $@
