# openssl (custom build from source)

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
OPENSSL_URL := $(GITHUB)/openssl/openssl/releases/download/openssl-$(OPENSSL_CUSTOM_VERSION)/openssl-$(OPENSSL_CUSTOM_VERSION).tar.gz

PKGS += openssl

$(TARBALLS)/openssl-$(OPENSSL_CUSTOM_VERSION).tar.gz:
	$(call download_pkg,$(OPENSSL_URL),openssl)

.sum-openssl: openssl-$(OPENSSL_CUSTOM_VERSION).tar.gz

openssl: openssl-$(OPENSSL_CUSTOM_VERSION).tar.gz .sum-openssl
	$(UNPACK)
	$(MOVE)

.openssl: openssl
	touch $@
