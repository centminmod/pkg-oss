# testcookie-nginx-module

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
TESTCOOKIE_NGINX_MODULE_URL := $(GITHUB)/kyprizel/testcookie-nginx-module/archive/$(TESTCOOKIE_NGINX_MODULE_GITHASH).tar.gz

PKGS += testcookie-nginx-module

$(TARBALLS)/testcookie-nginx-module-$(TESTCOOKIE_NGINX_MODULE_GITHASH).tar.gz:
	$(call download_pkg,$(TESTCOOKIE_NGINX_MODULE_URL),testcookie-nginx-module)

.sum-testcookie-nginx-module: testcookie-nginx-module-$(TESTCOOKIE_NGINX_MODULE_GITHASH).tar.gz

testcookie-nginx-module: testcookie-nginx-module-$(TESTCOOKIE_NGINX_MODULE_GITHASH).tar.gz .sum-testcookie-nginx-module
	$(UNPACK)
	$(MOVE)

.testcookie-nginx-module: testcookie-nginx-module
	touch $@
