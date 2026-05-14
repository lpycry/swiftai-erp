# SwiftAI ERP

AI-Powered Enterprise Resource Planning System for Small to Medium Businesses.

**Built with:** Go · Flutter · Docker · PostgreSQL · Claude AI

## Architecture

```
┌─────────────────────┐
│   Flutter Clients   │  iOS, Android, Web, Desktop
├─────────┬───────────┤
│  API Gateway (Go)  │  Auth, Rate Limit, Routing
├─────────┴───────────┤
│  Go Microservices   │  Auth, Finance, Logistics,...
├─────────────────────┤
│   NATS Event Bus    │  Async Domain Events
├─────────────────────┤
│  PostgreSQL + Redis  │  Data & Cache
└─────────────────────┘
```

## Quick Start

### Prerequisites
- Go 1.22+
- Flutter 3.x
- Docker & Docker Compose

### Setup

```bash
# 1. Start infrastructure
make dev-up

# 2. Run database migrations
make db-migrate

# 3. Install backend dependencies
make backend-deps

# 4. Get Flutter packages
make frontend-get

# 5. Start auth service
make backend-run-auth

# 6. Start API gateway (new terminal)
make backend-run-gateway

# 7. Start Flutter app (new terminal)
make frontend-run
```

Or all at once:
```bash
make init
```

## Project Structure

```
SwiftAIERP/
├── backend/                    # Go microservices
│   ├── cmd/                   # Entry points
│   │   ├── api-gateway/      # API Gateway
│   │   └── auth-service/     # Auth & RBAC service
│   ├── internal/              # Internal packages
│   │   ├── auth/             # Authentication logic
│   │   ├── rbac/             # Role-based access control
│   │   ├── database/         # DB connections
│   │   ├── middleware/       # HTTP middleware
│   │   ├── config/           # Configuration
│   │   └── models/           # Domain models
│   ├── pkg/                   # Shared packages
│   │   ├── jwt/              # JWT utilities
│   │   ├── response/         # API response helpers
│   ├── migrations/            # SQL migrations
│   └── config/                # Config files
├── frontend/                   # Flutter app
│   └── lib/
│       ├── core/              # Core framework
│       │   ├── theme/        # Material 3 theme
│       │   ├── router/       # Navigation
│       │   ├── services/     # API services
│       │   └── widgets/      # Shared widgets
│       └── features/         # Feature modules
│           ├── auth/         # Login, Register
│           ├── dashboard/    # Main dashboard
│           └── settings/     # User settings
├── deploy/                    # Deployment configs
│   ├── docker/               # Docker bake config
│   └── k8s/                  # Kubernetes manifests
└── docs/                      # Documentation
```

## Development Phases

| Phase | Duration | Deliverables |
|-------|----------|-------------|
| Foundation & Finance Core | Months 1-4 | Auth, GL, AP, AR, Reports |
| AI & Mobile Experience | Months 5-8 | AI Journal Entry, Flutter polish |
| Logistics, Procurement & Sales | Months 9-13 | WMS, PO, Sales, Lite Production |
| AI, Analytics & Scale | Months 14-18 | Forecasting, Anomaly Detection, GA |

## API Endpoints

### Auth Service (`/api/v1/auth`)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Register new company |
| POST | `/auth/login` | User login |
| POST | `/auth/refresh` | Refresh access token |
| GET | `/auth/me` | Current user info |

### RBAC (`/api/v1`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/roles` | List roles |
| POST | `/roles` | Create role |
| POST | `/roles/assign` | Assign user to role |
| GET | `/users/:id/permissions` | Get user permissions |

## License

Internal - Confidential
