# nginx-dav-ext-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_DAV_EXT_MODULE_URL := $(GITHUB)/arut/nginx-dav-ext-module/archive/v$(NGINX_DAV_EXT_MODULE_VERSION).tar.gz

PKGS += nginx-dav-ext-module

$(TARBALLS)/nginx-dav-ext-module-$(NGINX_DAV_EXT_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_DAV_EXT_MODULE_URL),nginx-dav-ext-module)

.sum-nginx-dav-ext-module: nginx-dav-ext-module-$(NGINX_DAV_EXT_MODULE_VERSION).tar.gz

nginx-dav-ext-module: nginx-dav-ext-module-$(NGINX_DAV_EXT_MODULE_VERSION).tar.gz .sum-nginx-dav-ext-module
	$(UNPACK)
	$(MOVE)

.nginx-dav-ext-module: nginx-dav-ext-module
	touch $@
