# nginx-module-vts

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_MODULE_VTS_URL := $(GITHUB)/vozlt/nginx-module-vts/archive/v$(NGINX_MODULE_VTS_VERSION).tar.gz

PKGS += nginx-module-vts

$(TARBALLS)/nginx-module-vts-$(NGINX_MODULE_VTS_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_MODULE_VTS_URL),nginx-module-vts)

.sum-nginx-module-vts: nginx-module-vts-$(NGINX_MODULE_VTS_VERSION).tar.gz

nginx-module-vts: nginx-module-vts-$(NGINX_MODULE_VTS_VERSION).tar.gz .sum-nginx-module-vts
	$(UNPACK)
	$(MOVE)

.nginx-module-vts: nginx-module-vts
	touch $@
