.PHONY: misc dev-up dev-down check spec

misc:
	brew install hey
dev-up:
	docker-compose up -d
dev-down:
	docker-compose down
reload-proxy:
	docker-compose exec proxy openresty -s reload

check:
	docker-compose exec -T -w /app proxy scripts/check

# use --filter PATTERN flag to focus on matching tests only
spec:
	docker-compose exec -T -w /app proxy scripts/spec $(ARGS)
