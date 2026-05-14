.PHONY: dev dev-up dev-down build test lint clean

# === Development ===

dev-up:
	docker compose up -d postgres redis nats minio timescaledb meilisearch

dev-down:
	docker compose down

dev-logs:
	docker compose logs -f

# === Backend ===

backend-deps:
	cd backend && go mod tidy

backend-run-auth:
	cd backend && go run ./cmd/auth-service

backend-run-gateway:
	cd backend && go run ./cmd/api-gateway

backend-air:
	cd backend && air

backend-test:
	cd backend && go test -v -race -count=1 ./...

backend-lint:
	cd backend && golangci-lint run

backend-build:
	cd backend && go build -o bin/ ./cmd/...

# === Frontend ===

frontend-get:
	cd frontend && flutter pub get

frontend-run:
	cd frontend && flutter run

frontend-run-web:
	cd frontend && flutter run -d chrome

frontend-build:
	cd frontend && flutter build apk

frontend-test:
	cd frontend && flutter test

frontend-analyze:
	cd frontend && flutter analyze

# === Docker ===

docker-build:
	docker compose build

docker-build-bake:
	docker buildx bake -f deploy/docker/docker-bake.hcl

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-clean:
	docker compose down -v

# === Database ===

db-migrate:
	cd backend && PGPASSWORD=swiftai_dev_pass psql -h localhost -U swiftai -d swiftai_erp -f migrations/001_init.sql

db-seed:
	cd backend && go run ./seeds

db-console:
	psql -h localhost -U swiftai -d swiftai_erp

# === Quality ===

test: backend-test frontend-test

lint: backend-lint frontend-analyze

clean:
	cd backend && rm -rf tmp bin
	cd frontend && flutter clean

# === Docs ===

docs-serve:
	npx docsify serve docs

# === All-in-One ===

init: dev-up db-migrate backend-deps frontend-get
	@echo "SwiftAI ERP development environment ready!"
