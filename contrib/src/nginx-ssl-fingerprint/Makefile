# nginx-ssl-fingerprint

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGINX_SSL_FINGERPRINT_URL := $(GITHUB)/centminmod/nginx-ssl-fingerprint/archive/v$(NGINX_SSL_FINGERPRINT_VERSION).tar.gz

PKGS += nginx-ssl-fingerprint

$(TARBALLS)/nginx-ssl-fingerprint-$(NGINX_SSL_FINGERPRINT_VERSION).tar.gz:
	$(call download_pkg,$(NGINX_SSL_FINGERPRINT_URL),nginx-ssl-fingerprint)

.sum-nginx-ssl-fingerprint: nginx-ssl-fingerprint-$(NGINX_SSL_FINGERPRINT_VERSION).tar.gz

nginx-ssl-fingerprint: nginx-ssl-fingerprint-$(NGINX_SSL_FINGERPRINT_VERSION).tar.gz .sum-nginx-ssl-fingerprint
	$(UNPACK)
	$(MOVE)

.nginx-ssl-fingerprint: nginx-ssl-fingerprint
	touch $@
