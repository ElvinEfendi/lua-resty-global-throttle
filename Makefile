.PHONY: image

image:
	docker build -t test-cli .

test:
	docker run -w /lua --rm -it -v ${PWD}:/lua test-cli prove -r t/
