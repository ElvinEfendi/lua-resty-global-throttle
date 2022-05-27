PREFIX ?=          /usr/local
LUA_INCLUDE_DIR ?= $(PREFIX)/include
LUA_LIB_DIR ?=     $(PREFIX)/lib/lua/$(LUA_VERSION)
INSTALL ?= install

.PHONY: install misc dev-up dev-down check spec release

install:
	$(INSTALL) -d $(DESTDIR)/$(LUA_LIB_DIR)/resty
	$(INSTALL) -d $(DESTDIR)/$(LUA_LIB_DIR)/resty/global_throttle
	$(INSTALL) -d $(DESTDIR)/$(LUA_LIB_DIR)/resty/global_throttle/store
	$(INSTALL) lib/resty/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty
	$(INSTALL) lib/resty/global_throttle/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty/global_throttle
	$(INSTALL) lib/resty/global_throttle/store/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty/global_throttle/store

misc:
	brew install hey
dev-up:
	docker-compose up -d
dev-down:
	docker-compose down
dev-build:
	docker-compose up -d --build
reload-proxy:
	docker-compose exec proxy openresty -s reload

check:
	docker-compose exec -T -w /global_throttle proxy scripts/check

# use --filter PATTERN flag to focus on matching tests only
spec:
	docker-compose exec -T -w /global_throttle proxy scripts/spec $(ARGS)

release:
	@echo "bump version and tag in rockspec"
	@echo "rename rockspec to include the new version"
	@echo "grep for VERSION in lib and bump the versions there"
	@echo "create a release tag in github interface"
	@echo "run 'luarocks pack lua-resty-global-throttle-<new version>.rockspec' to generate .rock file"
	@echo "Open https://luarocks.org/upload and upload the new .rockspec and .rock there"
