# Docker Bake - Multi-service build
group "default" {
  targets = ["api-gateway", "auth-service"]
}

target "api-gateway" {
  context = "../../backend"
  dockerfile = "../../backend/Dockerfile"
  target = "api-gateway"
  tags = ["swiftai-erp/api-gateway:latest"]
}

target "auth-service" {
  context = "../../backend"
  dockerfile = "../../backend/Dockerfile"
  target = "auth-service"
  tags = ["swiftai-erp/auth-service:latest"]
}
