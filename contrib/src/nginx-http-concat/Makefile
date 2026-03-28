# nginx-http-concat

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_HTTP_CONCAT_URL := $(GITHUB)/alibaba/nginx-http-concat/archive/$(NGINX_HTTP_CONCAT_VERSION).tar.gz

PKGS += nginx-http-concat

$(TARBALLS)/nginx-http-concat-$(NGINX_HTTP_CONCAT_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_HTTP_CONCAT_URL),nginx-http-concat)

.sum-nginx-http-concat: nginx-http-concat-$(NGINX_HTTP_CONCAT_VERSION).tar.gz

nginx-http-concat: nginx-http-concat-$(NGINX_HTTP_CONCAT_VERSION).tar.gz .sum-nginx-http-concat
	$(UNPACK)
	$(MOVE)

.nginx-http-concat: nginx-http-concat
	touch $@
