package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	pmodels "github.com/swiftai-erp/backend/internal/position/models"
)

type PositionRepo struct {
	db *pgxpool.Pool
}

func NewPositionRepo(db *pgxpool.Pool) *PositionRepo {
	return &PositionRepo{db: db}
}

const posSelectCols = `id, tenant_id, position_code, position_title,
	org_unit_id, parent_position_id,
	is_active, valid_from::text, COALESCE(valid_to::text,'') as valid_to,
	created_at, updated_at`

func (r *PositionRepo) Create(ctx context.Context, p *pmodels.Position) error {
	query := `
		INSERT INTO positions (id, tenant_id, position_code, position_title, org_unit_id, parent_position_id, is_active, valid_from, valid_to, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8::date, NULLIF($9,'')::date, $10, $11)
	`
	_, err := r.db.Exec(ctx, query,
		p.ID, p.TenantID, p.PositionCode, p.PositionTitle,
		p.OrgUnitID, p.ParentPositionID, p.IsActive,
		p.ValidFrom, p.ValidTo, p.CreatedAt, p.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("create position: %w", err)
	}
	return nil
}

func (r *PositionRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*pmodels.Position, error) {
	query := `SELECT ` + posSelectCols + ` FROM positions WHERE id = $1 AND tenant_id = $2`
	p := &pmodels.Position{}
	err := r.db.QueryRow(ctx, query, id, tenantID).Scan(
		&p.ID, &p.TenantID, &p.PositionCode, &p.PositionTitle,
		&p.OrgUnitID, &p.ParentPositionID,
		&p.IsActive, &p.ValidFrom, &p.ValidTo,
		&p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get position: %w", err)
	}
	return p, nil
}

func (r *PositionRepo) List(ctx context.Context, tenantID uuid.UUID, search string) ([]*pmodels.Position, error) {
	var rows pgx.Rows
	var err error

	if search == "" {
		query := `SELECT ` + posSelectCols + ` FROM positions WHERE tenant_id = $1 ORDER BY position_code`
		rows, err = r.db.Query(ctx, query, tenantID)
	} else {
		query := `SELECT ` + posSelectCols + ` FROM positions WHERE tenant_id = $1
			AND (position_code ILIKE $2 OR position_title ILIKE $2) ORDER BY position_code`
		like := "%" + search + "%"
		rows, err = r.db.Query(ctx, query, tenantID, like)
	}
	if err != nil {
		return nil, fmt.Errorf("list positions: %w", err)
	}
	defer rows.Close()
	return scanPositions(rows)
}

func (r *PositionRepo) ListTree(ctx context.Context, tenantID uuid.UUID) ([]*pmodels.PositionNode, error) {
	all, err := r.List(ctx, tenantID, "")
	if err != nil {
		return nil, err
	}
	return buildPosTree(all), nil
}

func (r *PositionRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *pmodels.UpdatePositionRequest) (*pmodels.Position, error) {
	setClauses := make([]string, 0, 6)
	args := []interface{}{}
	argIdx := 1

	if req.PositionTitle != "" {
		setClauses = append(setClauses, fmt.Sprintf("position_title = $%d", argIdx))
		args = append(args, req.PositionTitle)
		argIdx++
	}
	if req.OrgUnitID != "" {
		setClauses = append(setClauses, fmt.Sprintf("org_unit_id = $%d", argIdx))
		args = append(args, req.OrgUnitID)
		argIdx++
	} else if req.OrgUnitID == "__null__" {
		setClauses = append(setClauses, "org_unit_id = NULL")
	}
	if req.ParentPositionID != "" {
		setClauses = append(setClauses, fmt.Sprintf("parent_position_id = $%d", argIdx))
		args = append(args, req.ParentPositionID)
		argIdx++
	} else if req.ParentPositionID == "__null__" {
		setClauses = append(setClauses, "parent_position_id = NULL")
	}
	if req.IsActive != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_active = $%d", argIdx))
		args = append(args, *req.IsActive)
		argIdx++
	}
	if req.ValidFrom != "" {
		setClauses = append(setClauses, fmt.Sprintf("valid_from = $%d::date", argIdx))
		args = append(args, req.ValidFrom)
		argIdx++
	}
	if req.ValidTo != "" {
		setClauses = append(setClauses, fmt.Sprintf("valid_to = NULLIF($%d,'')::date", argIdx))
		args = append(args, req.ValidTo)
		argIdx++
	}

	if len(setClauses) == 0 {
		return r.GetByID(ctx, id, tenantID)
	}

	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++
	args = append(args, id, tenantID)

	query := fmt.Sprintf(`
		UPDATE positions SET %s
		WHERE id = $%d AND tenant_id = $%d
		RETURNING `+posSelectCols+`
	`, strings.Join(setClauses, ", "), argIdx, argIdx+1)

	p := &pmodels.Position{}
	err := r.db.QueryRow(ctx, query, args...).Scan(
		&p.ID, &p.TenantID, &p.PositionCode, &p.PositionTitle,
		&p.OrgUnitID, &p.ParentPositionID,
		&p.IsActive, &p.ValidFrom, &p.ValidTo,
		&p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("update position: %w", err)
	}
	return p, nil
}

func (r *PositionRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	var childCount int
	r.db.QueryRow(ctx, "SELECT COUNT(*) FROM positions WHERE parent_position_id = $1", id).Scan(&childCount)
	if childCount > 0 {
		return fmt.Errorf("cannot delete position with %d child position(s)", childCount)
	}
	_, err := r.db.Exec(ctx, "DELETE FROM positions WHERE id = $1 AND tenant_id = $2", id, tenantID)
	if err != nil {
		return fmt.Errorf("delete position: %w", err)
	}
	return nil
}

// ── Helpers ──

func scanPositions(rows pgx.Rows) ([]*pmodels.Position, error) {
	var list []*pmodels.Position
	for rows.Next() {
		p := &pmodels.Position{}
		err := rows.Scan(
			&p.ID, &p.TenantID, &p.PositionCode, &p.PositionTitle,
			&p.OrgUnitID, &p.ParentPositionID,
			&p.IsActive, &p.ValidFrom, &p.ValidTo,
			&p.CreatedAt, &p.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scan position: %w", err)
		}
		list = append(list, p)
	}
	return list, nil
}

func buildPosTree(flat []*pmodels.Position) []*pmodels.PositionNode {
	nodeMap := make(map[uuid.UUID]*pmodels.PositionNode)
	var roots []*pmodels.PositionNode
	for _, p := range flat {
		nodeMap[p.ID] = &pmodels.PositionNode{Position: *p}
	}
	for _, p := range flat {
		node := nodeMap[p.ID]
		if p.ParentPositionID != nil {
			parent, ok := nodeMap[*p.ParentPositionID]
			if ok {
				parent.Children = append(parent.Children, node)
			} else {
				roots = append(roots, node)
			}
		} else {
			roots = append(roots, node)
		}
	}
	return roots
}
