# ngx_http_redis

include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/version
NGX_HTTP_REDIS_URL := $(GITHUB)/centminmod/ngx_http_redis/archive/$(NGX_HTTP_REDIS_VERSION).tar.gz

PKGS += ngx_http_redis

$(TARBALLS)/ngx_http_redis-$(NGX_HTTP_REDIS_VERSION).tar.gz:
	$(call download_pkg,$(NGX_HTTP_REDIS_URL),ngx_http_redis)

.sum-ngx_http_redis: ngx_http_redis-$(NGX_HTTP_REDIS_VERSION).tar.gz

ngx_http_redis: ngx_http_redis-$(NGX_HTTP_REDIS_VERSION).tar.gz .sum-ngx_http_redis
	$(UNPACK)
	$(MOVE)

.ngx_http_redis: ngx_http_redis
	touch $@
