# SwiftAI ERP — Documentation

## Overview
SwiftAI ERP is a next-generation AI-first ERP system for SMBs, built on Go microservices architecture with Flutter cross-platform frontend.

## Contents

### User Guide
- [SwiftAI ERP User Manual](SwiftAI_ERP_User_Manual.md)

### Architecture
- [System Architecture](architecture/system-architecture.md)
- [Multi-Tenancy Model](architecture/multi-tenancy.md)
- [Data Flow](architecture/data-flow.md)

### API
- [Authentication API](api/auth-api.md)
- [RBAC API](api/rbac-api.md)
- [API Conventions](api/conventions.md)

### Database
- [Schema Overview](database/schema.md)
- [Migration Guide](database/migrations.md)

### Development
- [Getting Started](../README.md)
- [Development Setup](development/setup.md)
- [Coding Standards](development/coding-standards.md)

### Operations
- [Deployment](operations/deployment.md)
- [Monitoring](operations/monitoring.md)
- [Backup & Recovery](operations/backup.md)

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Backend | Go 1.22+ |
| Frontend | Flutter 3.x (Dart) |
| Container | Docker + K8s |
| Database | PostgreSQL 16 + TimescaleDB |
| Cache | Redis 7 |
| Events | NATS JetStream |
| AI | Anthropic Claude |
| Storage | MinIO (S3-compatible) |
