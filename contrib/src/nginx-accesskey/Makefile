# nginx-accesskey

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_ACCESSKEY_URL := $(GITHUB)/Martchus/nginx-accesskey/archive/v$(NGINX_ACCESSKEY_VERSION).tar.gz

PKGS += nginx-accesskey

$(TARBALLS)/nginx-accesskey-$(NGINX_ACCESSKEY_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_ACCESSKEY_URL),nginx-accesskey)

.sum-nginx-accesskey: nginx-accesskey-$(NGINX_ACCESSKEY_VERSION).tar.gz

nginx-accesskey: nginx-accesskey-$(NGINX_ACCESSKEY_VERSION).tar.gz .sum-nginx-accesskey
	$(UNPACK)
	$(MOVE)

.nginx-accesskey: nginx-accesskey
	touch $@
