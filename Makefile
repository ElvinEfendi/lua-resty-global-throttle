.PHONY: image dev dev-pre dev-run
image:
	docker build -t test-cli .

dev:
	docker build -t throttle-dev -f dev/Dockerfile .
dev-pre:
	brew install hey
dev-run:
	docker run --rm -p 8080:8080 -v ${PWD}/lib:/usr/local/openresty/site/lualib -v ${PWD}/dev/nginx.conf:/etc/openresty/nginx.conf throttle-dev

.PHONY: check
check:
	scripts/check
.PHONY: test
test:
	scripts/test

.PHONY: spec
spec:
	scripts/spec
