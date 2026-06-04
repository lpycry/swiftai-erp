package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	dfmodels "github.com/swiftai-erp/backend/internal/dateformat/models"
)

type DateFormatRepo struct {
	db *pgxpool.Pool
}

func NewDateFormatRepo(db *pgxpool.Pool) *DateFormatRepo {
	return &DateFormatRepo{db: db}
}

const dfSelectCols = `id, tenant_id, format_code, display_name, date_pattern,
	separator, COALESCE(example_output,'') as example_output,
	sort_order, is_active, created_at, updated_at`

func (r *DateFormatRepo) Create(ctx context.Context, df *dfmodels.DateFormat) error {
	query := `
		INSERT INTO date_formats (id, tenant_id, format_code, display_name, date_pattern, separator, example_output, sort_order, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	_, err := r.db.Exec(ctx, query,
		df.ID, df.TenantID, df.FormatCode, df.DisplayName, df.DatePattern,
		df.Separator, df.ExampleOutput, df.SortOrder, df.IsActive,
		df.CreatedAt, df.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create date format: %w", err)
	}
	return nil
}

func (r *DateFormatRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*dfmodels.DateFormat, error) {
	df := &dfmodels.DateFormat{}
	err := r.db.QueryRow(ctx, `SELECT `+dfSelectCols+` FROM date_formats WHERE id = $1 AND tenant_id = $2`, id, tenantID).Scan(
		&df.ID, &df.TenantID, &df.FormatCode, &df.DisplayName, &df.DatePattern,
		&df.Separator, &df.ExampleOutput, &df.SortOrder, &df.IsActive,
		&df.CreatedAt, &df.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows { return nil, nil }
		return nil, fmt.Errorf("get date format: %w", err)
	}
	return df, nil
}

func (r *DateFormatRepo) List(ctx context.Context, tenantID uuid.UUID) ([]*dfmodels.DateFormat, error) {
	rows, err := r.db.Query(ctx, `SELECT `+dfSelectCols+` FROM date_formats WHERE tenant_id = $1 ORDER BY sort_order, format_code`, tenantID)
	if err != nil { return nil, fmt.Errorf("list date formats: %w", err) }
	defer rows.Close()
	var list []*dfmodels.DateFormat
	for rows.Next() {
		df := &dfmodels.DateFormat{}
		err := rows.Scan(&df.ID, &df.TenantID, &df.FormatCode, &df.DisplayName, &df.DatePattern,
			&df.Separator, &df.ExampleOutput, &df.SortOrder, &df.IsActive, &df.CreatedAt, &df.UpdatedAt)
		if err != nil { return nil, fmt.Errorf("scan date format: %w", err) }
		list = append(list, df)
	}
	return list, nil
}

func (r *DateFormatRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *dfmodels.UpdateDateFormatRequest) (*dfmodels.DateFormat, error) {
	setClauses := make([]string, 0, 6)
	args := []interface{}{}
	argIdx := 1

	if req.DisplayName != "" {
		setClauses = append(setClauses, fmt.Sprintf("display_name = $%d", argIdx))
		args = append(args, req.DisplayName); argIdx++
	}
	if req.DatePattern != "" {
		setClauses = append(setClauses, fmt.Sprintf("date_pattern = $%d", argIdx))
		args = append(args, req.DatePattern); argIdx++
	}
	if req.Separator != "" {
		setClauses = append(setClauses, fmt.Sprintf("separator = $%d", argIdx))
		args = append(args, req.Separator); argIdx++
	}
	if req.ExampleOutput != "" {
		setClauses = append(setClauses, fmt.Sprintf("example_output = $%d", argIdx))
		args = append(args, req.ExampleOutput); argIdx++
	}
	if req.SortOrder != nil {
		setClauses = append(setClauses, fmt.Sprintf("sort_order = $%d", argIdx))
		args = append(args, *req.SortOrder); argIdx++
	}
	if req.IsActive != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		args = append(args, *req.IsActive); argIdx++
	}

	if len(setClauses) == 0 { return r.GetByID(ctx, id, tenantID) }

	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now()); argIdx++
	args = append(args, id, tenantID)

	query := fmt.Sprintf(`UPDATE date_formats SET %s WHERE id = $%d AND tenant_id = $%d RETURNING `+dfSelectCols,
		strings.Join(setClauses, ", "), argIdx, argIdx+1)

	df := &dfmodels.DateFormat{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&df.ID, &df.TenantID, &df.FormatCode, &df.DisplayName, &df.DatePattern,
		&df.Separator, &df.ExampleOutput, &df.SortOrder, &df.IsActive,
		&df.CreatedAt, &df.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows { return nil, nil }
		return nil, fmt.Errorf("update date format: %w", err)
	}
	return df, nil
}

func (r *DateFormatRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM date_formats WHERE id = $1 AND tenant_id = $2", id, tenantID)
	if err != nil { return fmt.Errorf("delete date format: %w", err) }
	return nil
}

// SetActive sets one format as active and deactivates all others
func (r *DateFormatRepo) SetActive(ctx context.Context, id, tenantID uuid.UUID) (*dfmodels.DateFormat, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil { return nil, fmt.Errorf("begin tx: %w", err) }
	defer tx.Rollback(ctx)

	// Deactivate all formats for this tenant
	_, err = tx.Exec(ctx, "UPDATE date_formats SET is_active = false, updated_at = NOW() WHERE tenant_id = $1", tenantID)
	if err != nil { return nil, fmt.Errorf("deactivate all: %w", err) }

	// Activate target by just updating and re-fetching
	_, err = tx.Exec(ctx, "UPDATE date_formats SET is_active = true, updated_at = NOW() WHERE id = $1 AND tenant_id = $2", id, tenantID)
	if err != nil { return nil, fmt.Errorf("activate target: %w", err) }

	if err := tx.Commit(ctx); err != nil { return nil, fmt.Errorf("commit: %w", err) }
	return r.GetByID(ctx, id, tenantID)
}
