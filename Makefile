.PHONY: image

image:
	docker build -t test-cli .

.PHONY: test

test:
	docker run -w /lua --rm -it -v ${PWD}:/lua test-cli prove -r t/

.PHONY: spec

spec:
	$(eval CONTAINER_ID = $(shell docker run -d -p 11211:11211 --rm --name memcached bitnami/memcached:latest))
	$(eval MEMCACHED_HOST = $(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CONTAINER_ID)))

	# wait for memcached to be ready
	@sleep 2

	docker run -w /lua --rm -it -v ${PWD}:/lua -e MEMCACHED_HOST=$(MEMCACHED_HOST) test-cli \
		resty \
			-I /lua/lib \
			--shdict "my_global_throttle 1M" \
			spec/run.lua -o gtest -v spec/**/

	@docker stop $(CONTAINER_ID)
