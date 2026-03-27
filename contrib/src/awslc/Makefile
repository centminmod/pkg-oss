# aws-lc

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
AWSLC_URL := $(GITHUB)/aws/aws-lc/archive/refs/tags/v$(AWSLC_VERSION).tar.gz

PKGS += awslc

$(TARBALLS)/aws-lc-$(AWSLC_VERSION).tar.gz:
	$(call download_pkg,$(AWSLC_URL),awslc)

.sum-awslc: aws-lc-$(AWSLC_VERSION).tar.gz

awslc: aws-lc-$(AWSLC_VERSION).tar.gz .sum-awslc
	$(UNPACK)
	$(MOVE)

.awslc: awslc
	touch $@
