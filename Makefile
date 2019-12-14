.PHONY: image
image:
	docker build -t test-cli .

.PHONY: check
check:
	scripts/check
.PHONY: test
test:
	scripts/test

.PHONY: spec
spec:
	scripts/spec
