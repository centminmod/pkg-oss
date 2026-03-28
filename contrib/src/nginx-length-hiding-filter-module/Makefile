# nginx-length-hiding-filter-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_LENGTH_HIDING_FILTER_MODULE_URL := $(GITHUB)/nulab/nginx-length-hiding-filter-module/archive/$(NGINX_LENGTH_HIDING_FILTER_MODULE_VERSION).tar.gz

PKGS += nginx-length-hiding-filter-module

$(TARBALLS)/nginx-length-hiding-filter-module-$(NGINX_LENGTH_HIDING_FILTER_MODULE_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_LENGTH_HIDING_FILTER_MODULE_URL),nginx-length-hiding-filter-module)

.sum-nginx-length-hiding-filter-module: nginx-length-hiding-filter-module-$(NGINX_LENGTH_HIDING_FILTER_MODULE_VERSION).tar.gz

nginx-length-hiding-filter-module: nginx-length-hiding-filter-module-$(NGINX_LENGTH_HIDING_FILTER_MODULE_VERSION).tar.gz .sum-nginx-length-hiding-filter-module
	$(UNPACK)
	$(MOVE)

.nginx-length-hiding-filter-module: nginx-length-hiding-filter-module
	touch $@
