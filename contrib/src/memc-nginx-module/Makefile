# memc-nginx-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
MEMC_NGINX_MODULE_URL := $(GITHUB)/openresty/memc-nginx-module/archive/v$(MEMC_NGINX_MODULE_VERSION).tar.gz

PKGS += memc-nginx-module

$(TARBALLS)/memc-nginx-module-$(MEMC_NGINX_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(MEMC_NGINX_MODULE_URL),memc-nginx-module)

.sum-memc-nginx-module: memc-nginx-module-$(MEMC_NGINX_MODULE_VERSION).tar.gz

memc-nginx-module: memc-nginx-module-$(MEMC_NGINX_MODULE_VERSION).tar.gz .sum-memc-nginx-module
	$(UNPACK)
	$(MOVE)

.memc-nginx-module: memc-nginx-module
	touch $@
