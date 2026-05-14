package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type AuthValueRepo struct {
	db *pgxpool.Pool
}

func NewAuthValueRepo(db *pgxpool.Pool) *AuthValueRepo {
	return &AuthValueRepo{db: db}
}

func (r *AuthValueRepo) SetAuthValue(ctx context.Context, val *models.RoleAuthValue) error {
	query := `
		INSERT INTO role_auth_values (
			id, role_id, auth_object_id,
			activity_create, activity_read, activity_update, activity_delete,
			activity_approve, activity_print, activity_transfer, activity_close,
			field_values, field_ranges
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		ON CONFLICT (role_id, auth_object_id) DO UPDATE SET
			activity_create = EXCLUDED.activity_create,
			activity_read = EXCLUDED.activity_read,
			activity_update = EXCLUDED.activity_update,
			activity_delete = EXCLUDED.activity_delete,
			activity_approve = EXCLUDED.activity_approve,
			activity_print = EXCLUDED.activity_print,
			activity_transfer = EXCLUDED.activity_transfer,
			activity_close = EXCLUDED.activity_close,
			field_values = EXCLUDED.field_values,
			field_ranges = EXCLUDED.field_ranges
	`
	fv, _ := json.Marshal(val.FieldValues)
	fr, _ := json.Marshal(val.FieldRanges)

	_, err := r.db.Exec(ctx, query,
		val.ID, val.RoleID, val.AuthObjectID,
		val.ActivityCreate, val.ActivityRead, val.ActivityUpdate, val.ActivityDelete,
		val.ActivityApprove, val.ActivityPrint, val.ActivityTransfer, val.ActivityClose,
		string(fv), string(fr))
	return err
}

func (r *AuthValueRepo) GetAuthValues(ctx context.Context, roleID uuid.UUID) ([]*models.RoleAuthValue, error) {
	query := `
		SELECT id, role_id, auth_object_id,
		       activity_create, activity_read, activity_update, activity_delete,
		       activity_approve, activity_print, activity_transfer, activity_close,
		       field_values, field_ranges
		FROM role_auth_values WHERE role_id = $1
	`
	rows, err := r.db.Query(ctx, query, roleID)
	if err != nil {
		return nil, fmt.Errorf("get auth values: %w", err)
	}
	defer rows.Close()

	return scanAuthValues(rows)
}

// GetAuthValuesForRoleIDs returns all auth values for a list of role IDs (used in permission engine).
func (r *AuthValueRepo) GetAuthValuesForRoleIDs(ctx context.Context, roleIDs []uuid.UUID) ([]*models.RoleAuthValue, error) {
	if len(roleIDs) == 0 {
		return nil, nil
	}
	query := `
		SELECT rav.id, rav.role_id, rav.auth_object_id,
		       rav.activity_create, rav.activity_read, rav.activity_update, rav.activity_delete,
		       rav.activity_approve, rav.activity_print, rav.activity_transfer, rav.activity_close,
		       rav.field_values, rav.field_ranges
		FROM role_auth_values rav
		INNER JOIN auth_objects ao ON ao.id = rav.auth_object_id
		WHERE rav.role_id = ANY($1) AND ao.is_active = true
	`
	rows, err := r.db.Query(ctx, query, roleIDs)
	if err != nil {
		return nil, fmt.Errorf("get auth values for roles: %w", err)
	}
	defer rows.Close()

	return scanAuthValues(rows)
}

func scanAuthValues(rows pgx.Rows) ([]*models.RoleAuthValue, error) {
	var vals []*models.RoleAuthValue
	for rows.Next() {
		v := &models.RoleAuthValue{
			FieldValues: make(map[string]string),
			FieldRanges: make(map[string]models.FieldRange),
		}
		var fvStr, frStr string
		if err := rows.Scan(
			&v.ID, &v.RoleID, &v.AuthObjectID,
			&v.ActivityCreate, &v.ActivityRead, &v.ActivityUpdate, &v.ActivityDelete,
			&v.ActivityApprove, &v.ActivityPrint, &v.ActivityTransfer, &v.ActivityClose,
			&fvStr, &frStr); err != nil {
			return nil, fmt.Errorf("scan auth value: %w", err)
		}
		if fvStr != "" {
			_ = json.Unmarshal([]byte(fvStr), &v.FieldValues)
		}
		if frStr != "" {
			_ = json.Unmarshal([]byte(frStr), &v.FieldRanges)
		}
		vals = append(vals, v)
	}
	return vals, nil
}

func (r *AuthValueRepo) DeleteAuthValue(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM role_auth_values WHERE id=$1`, id)
	return err
}
