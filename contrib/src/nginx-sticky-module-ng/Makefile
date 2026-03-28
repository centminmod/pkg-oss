# nginx-sticky-module-ng

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_STICKY_MODULE_NG_URL := $(GITHUB)/Refinitiv/nginx-sticky-module-ng/archive/$(NGINX_STICKY_MODULE_NG_GITHASH).tar.gz

PKGS += nginx-sticky-module-ng

$(TARBALLS)/nginx-sticky-module-ng-$(NGINX_STICKY_MODULE_NG_GITHASH).tar.gz:
	$(call download_pkg,$(NGINX_STICKY_MODULE_NG_URL),nginx-sticky-module-ng)

.sum-nginx-sticky-module-ng: nginx-sticky-module-ng-$(NGINX_STICKY_MODULE_NG_GITHASH).tar.gz

nginx-sticky-module-ng: nginx-sticky-module-ng-$(NGINX_STICKY_MODULE_NG_GITHASH).tar.gz .sum-nginx-sticky-module-ng
	$(UNPACK)
	$(MOVE)

.nginx-sticky-module-ng: nginx-sticky-module-ng
	touch $@
