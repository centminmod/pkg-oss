# nginx_upstream_check_module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_UPSTREAM_CHECK_MODULE_URL := $(GITHUB)/yaoweibin/nginx_upstream_check_module/archive/v$(NGINX_UPSTREAM_CHECK_MODULE_VERSION).tar.gz

PKGS += nginx_upstream_check_module

$(TARBALLS)/nginx_upstream_check_module-$(NGINX_UPSTREAM_CHECK_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_UPSTREAM_CHECK_MODULE_URL),nginx_upstream_check_module)

.sum-nginx_upstream_check_module: nginx_upstream_check_module-$(NGINX_UPSTREAM_CHECK_MODULE_VERSION).tar.gz

nginx_upstream_check_module: nginx_upstream_check_module-$(NGINX_UPSTREAM_CHECK_MODULE_VERSION).tar.gz .sum-nginx_upstream_check_module
	$(UNPACK)
	$(MOVE)

.nginx_upstream_check_module: nginx_upstream_check_module
	touch $@
