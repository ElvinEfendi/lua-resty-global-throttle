.PHONY: image

image:
	docker build -t test-cli .

.PHONY: test

test:
	docker run -w /lua --rm -it -v ${PWD}:/lua test-cli prove -r t/

.PHONY: spec

spec:
	docker run -w /lua --rm -it -v ${PWD}:/lua test-cli resty -I /lua/lib spec/run.lua -o gtest -v spec/**/
