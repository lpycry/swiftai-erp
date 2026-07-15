package repository

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AuditRepo struct {
	db *pgxpool.Pool
}

func NewAuditRepo(db *pgxpool.Pool) *AuditRepo {
	return &AuditRepo{db: db}
}

func (r *AuditRepo) Record(ctx context.Context, tenantID uuid.UUID, userID *uuid.UUID, action, entityType string, entityID *uuid.UUID, oldValues, newValues interface{}, ip, userAgent string) {
	oldJSON, _ := json.Marshal(oldValues)
	newJSON, _ := json.Marshal(newValues)
	if oldValues == nil {
		oldJSON = nil
	}
	if newValues == nil {
		newJSON = nil
	}
	_, _ = r.db.Exec(ctx, `
		INSERT INTO audit_log (
			id, tenant_id, user_id, action, entity_type, entity_id,
			old_values, new_values, ip_address, user_agent, created_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW())`,
		uuid.New(), tenantID, userID, action, entityType, entityID,
		oldJSON, newJSON, ip, userAgent)
}
