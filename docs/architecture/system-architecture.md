# System Architecture

## High-Level Design

SwiftAI ERP follows a **Domain-Driven Microservices** architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌─────────┐ ┌──────────┐ ┌──────┐ ┌─────────────┐    │
│  │  iOS    │ │  Android  │ │ Web  │ │  Desktop     │    │
│  └────┬────┘ └────┬─────┘ └──┬───┘ └──────┬───────┘    │
│       └───────────┴──────────┴─────────────┘            │
│                       Flutter                            │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTPS / WSS
┌──────────────────────────▼──────────────────────────────┐
│                    API Gateway Layer                      │
│              Go · JWT Auth · Rate Limit · Route           │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│                    Service Layer (Go)                     │
│  ┌──────┐ ┌────────┐ ┌──────────┐ ┌──────┐ ┌──────┐   │
│  │ Auth │ │Finance │ │Logistics │ │Sales │ │  AI  │   │
│  └──────┘ └────────┘ └──────────┘ └──────┘ └──────┘   │
└──────────┬──────────────────────────────────────────────┘
           │ NATS Event Bus
┌──────────▼──────────────────────────────────────────────┐
│                    Data Layer                             │
│  ┌──────────┐ ┌───────┐ ┌────────┐ ┌──────┐            │
│  │PostgreSQL│ │ Redis │ │Timescale│ │MinIO │            │
│  └──────────┘ └───────┘ └────────┘ └──────┘            │
└─────────────────────────────────────────────────────────┘
```

## Key Design Decisions

1. **Schema-per-tenant multitenancy**: Strong data isolation with shared infrastructure
2. **NATS JetStream event bus**: Async domain events for eventual consistency
3. **CQRS-ready**: Separate read/write paths enabled by event-driven architecture
4. **Stateless services**: Auth via JWT, horizontal scaling

## Service Boundaries

| Service | Responsibility | Database |
|---------|---------------|----------|
| API Gateway | Auth, routing, rate limiting | Redis (cache) |
| Auth Service | Users, roles, permissions | Auth schema |
| Finance Service | GL, AP, AR, CO, Reports | Finance schema |
| Logistics Service | Warehouse, inventory | Logistics schema |
| Sales Service | Orders, customers | Sales schema |
| AI Service | Claude AI orchestration | AI schema |
