# ============================================================
# SwiftAI ERP - Docker Image
# Multi-stage build for all Go microservices
# ============================================================

# ---- Builder ----
FROM  golang:1.26-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /build

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build target
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /bin/auth-service ./cmd/auth-service

# ---- Auth Service ----
FROM alpine:3.19 AS auth-service
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /bin/auth-service /app/auth-service
COPY --from=builder /build/config /app/config
EXPOSE 8081
WORKDIR /app
CMD ["./auth-service"]

# ---- Development ----
FROM golang:1.22 AS dev
RUN go install github.com/air-verse/air@latest
WORKDIR /app
CMD ["air", "--config", ".air.toml"]
