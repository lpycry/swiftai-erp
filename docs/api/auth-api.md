# Authentication API

## Base URL
Development: `http://localhost:8080/api/v1/auth`

## Endpoints

### POST /auth/register
Create a new company tenant with admin user.

**Request:**
```json
{
  "email": "admin@company.com",
  "password": "securePassword123",
  "display_name": "John Admin",
  "company_name": "Acme Corp"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "access_expires_in": 900,
    "refresh_expires_in": 604800,
    "token_type": "Bearer",
    "user": {
      "id": "uuid",
      "email": "admin@company.com",
      "display_name": "John Admin",
      "tenant_id": "uuid",
      "roles": ["admin"]
    }
  }
}
```

### POST /auth/login
Authenticate with email and password.

**Request:**
```json
{
  "email": "admin@company.com",
  "password": "securePassword123"
}
```

**Response (200):**
Same structure as register response.

### POST /auth/refresh
Refresh an expired access token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "access_token": "new_access_token",
    "refresh_token": "new_refresh_token",
    "access_expires_in": 900,
    "refresh_expires_in": 604800,
    "token_type": "Bearer"
  }
}
```

### GET /auth/me
Get current authenticated user info.
**Headers:** `Authorization: Bearer <token>`

## Error Codes
| Status | Code | Description |
|--------|------|-------------|
| 400 | - | Invalid request body |
| 401 | - | Invalid credentials |
| 409 | - | Email already registered |
| 500 | - | Internal server error |

## Authentication Flow

1. User registers or logs in → receives access + refresh tokens
2. Access token (15min TTL) sent as `Authorization: Bearer <token>`
3. When access expires → use refresh token to get new pair
4. Refresh tokens stored in Redis, invalidated on logout
