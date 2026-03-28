# nginx-http-rdns

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_HTTP_RDNS_URL := $(GITHUB)/flant/nginx-http-rdns/archive/$(NGINX_HTTP_RDNS_GITHASH).tar.gz

PKGS += nginx-http-rdns

$(TARBALLS)/nginx-http-rdns-$(NGINX_HTTP_RDNS_GITHASH).tar.gz:
	$(call download_pkg,$(NGINX_HTTP_RDNS_URL),nginx-http-rdns)

.sum-nginx-http-rdns: nginx-http-rdns-$(NGINX_HTTP_RDNS_GITHASH).tar.gz

nginx-http-rdns: nginx-http-rdns-$(NGINX_HTTP_RDNS_GITHASH).tar.gz .sum-nginx-http-rdns
	$(UNPACK)
	$(MOVE)

.nginx-http-rdns: nginx-http-rdns
	touch $@
