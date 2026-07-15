package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	prodmodels "github.com/swiftai-erp/backend/internal/production/models"
)

// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
// BOMRepo — rewritten per FSD §3 & §4
// ─────────────────────────────────────────────────────────────────

type BOMRepo struct {
	db *pgxpool.Pool
}

func NewBOMRepo(db *pgxpool.Pool) *BOMRepo {
	return &BOMRepo{db: db}
}

// Create saves a BOM header with items in a single transaction.
// It performs an anti-loop check (FSD §4.1) before inserting.
func (r *BOMRepo) Create(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.CreateBOMRequest) (*prodmodels.BOMHeader, error) {
	// Defaults
	usage := req.BOMUsage
	if usage == "" {
		usage = "PRODUCTION"
	}
	baseQty := req.BaseQty
	if baseQty <= 0 {
		baseQty = 1.0000
	}
	var validFrom time.Time
	if req.ValidFrom != "" {
		var err error
		validFrom, err = parseTimeFlexible(req.ValidFrom)
		if err != nil {
			return nil, fmt.Errorf("invalid valid_from: %w", err)
		}
	} else {
		validFrom = time.Now()
	}
	var validTo time.Time
	if req.ValidTo != "" {
		var err error
		validTo, err = parseTimeFlexible(req.ValidTo)
		if err != nil {
			return nil, fmt.Errorf("invalid valid_to: %w", err)
		}
	} else {
		validTo = time.Date(2099, 12, 31, 23, 59, 59, 0, time.UTC)
	}

	// Anti-loop check (FSD §4.1): build directed graph and DFS
	if err := r.checkAntiLoop(ctx, tenantID, req.MaterialID, req.Items); err != nil {
		return nil, err
	}

	h := &prodmodels.BOMHeader{
		BOMID:             uuid.New(),
		TenantID:          tenantID,
		MaterialID:        req.MaterialID,
		BOMVersion:        req.BOMVersion,
		BOMUsage:          usage,
		Status:            "NEW",
		BaseQty:           baseQty,
		ValidFrom:         validFrom,
		ValidTo:           validTo,
		Description:       req.Description,
		IsActive:          req.IsActive,
		RoutingTemplateID: req.RoutingTemplateID,
		CreatedBy:         &userID,
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO bom_headers (bom_id, tenant_id, material_id, routing_template_id, bom_version,
			bom_usage, status, base_qty, valid_from, valid_to,
			description, is_active,
			created_by, updated_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$13,NOW(),NOW())
	`, h.BOMID, h.TenantID, h.MaterialID, h.RoutingTemplateID, h.BOMVersion,
		h.BOMUsage, h.Status, h.BaseQty, h.ValidFrom, h.ValidTo,
		h.Description, h.IsActive,
		h.CreatedBy)
	if err != nil {
		return nil, fmt.Errorf("insert bom_header: %w", err)
	}

	for _, itemReq := range req.Items {
		item, err := r.insertItemTx(ctx, tx, h.BOMID, &itemReq)
		if err != nil {
			return nil, err
		}
		// Fetch component name/sku
		r.enrichComponent(ctx, item)
		h.Items = append(h.Items, *item)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit tx: %w", err)
	}

	// Fetch product name/sku for material
	r.enrichMaterial(ctx, h)
	return h, nil
}

// GetByID returns a BOM header with its items.
func (r *BOMRepo) GetByID(ctx context.Context, bomID, tenantID uuid.UUID) (*prodmodels.BOMHeader, error) {
	h := &prodmodels.BOMHeader{}
	err := r.db.QueryRow(ctx, `
		SELECT bh.bom_id, bh.tenant_id, bh.material_id,
			bh.routing_template_id,
			COALESCE(p.name,''), COALESCE(p.sku,''),
			COALESCE(rt.template_name,''),
			bh.bom_version, bh.bom_usage, bh.status, bh.base_qty,
			bh.valid_from, bh.valid_to,
			COALESCE(bh.description,''), bh.is_active,
			bh.created_by, bh.updated_by, bh.created_at, bh.updated_at
		FROM bom_headers bh
		LEFT JOIN products p ON p.id = bh.material_id
		LEFT JOIN routing_templates rt ON rt.id = bh.routing_template_id
		WHERE bh.bom_id = $1 AND bh.tenant_id = $2
	`, bomID, tenantID).Scan(
		&h.BOMID, &h.TenantID, &h.MaterialID,
		&h.RoutingTemplateID,
		&h.MaterialName, &h.MaterialSKU,
		&h.RoutingTemplateName,
		&h.BOMVersion, &h.BOMUsage, &h.Status, &h.BaseQty,
		&h.ValidFrom, &h.ValidTo,
		&h.Description, &h.IsActive,
		&h.CreatedBy, &h.UpdatedBy, &h.CreatedAt, &h.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get bom_header: %w", err)
	}

	items, err := r.loadItems(ctx, bomID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("load bom items: %w", err)
	}
	h.Items = items
	return h, nil
}

// List returns BOM headers by tenant, optionally filtered by material_id and/or status.
func (r *BOMRepo) List(ctx context.Context, tenantID uuid.UUID, materialID *uuid.UUID, status string) ([]*prodmodels.BOMHeader, error) {
	query := `
		SELECT bh.bom_id, bh.tenant_id, bh.material_id,
			bh.routing_template_id,
			COALESCE(p.name,''), COALESCE(p.sku,''),
			COALESCE(rt.template_name,''),
			bh.bom_version, bh.bom_usage, bh.status, bh.base_qty,
			bh.valid_from, bh.valid_to,
			COALESCE(bh.description,''), bh.is_active,
			bh.created_by, bh.updated_by, bh.created_at, bh.updated_at
		FROM bom_headers bh
		LEFT JOIN products p ON p.id = bh.material_id
		LEFT JOIN routing_templates rt ON rt.id = bh.routing_template_id
		WHERE bh.tenant_id = $1
	`
	args := []interface{}{tenantID}
	argIdx := 2

	if materialID != nil {
		query += fmt.Sprintf(" AND bh.material_id = $%d", argIdx)
		args = append(args, *materialID)
		argIdx++
	}
	if status != "" {
		query += fmt.Sprintf(" AND bh.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	query += " ORDER BY bh.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list bom headers: %w", err)
	}
	defer rows.Close()

	var list []*prodmodels.BOMHeader
	for rows.Next() {
		h := &prodmodels.BOMHeader{}
		if err := rows.Scan(
			&h.BOMID, &h.TenantID, &h.MaterialID,
			&h.RoutingTemplateID,
			&h.MaterialName, &h.MaterialSKU,
			&h.RoutingTemplateName,
			&h.BOMVersion, &h.BOMUsage, &h.Status, &h.BaseQty,
			&h.ValidFrom, &h.ValidTo,
			&h.Description, &h.IsActive,
			&h.CreatedBy, &h.UpdatedBy, &h.CreatedAt, &h.UpdatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, h)
	}
	return list, nil
}

// Update modifies a BOM header. Only allowed if status != 'ACTIVE'.
func (r *BOMRepo) Update(ctx context.Context, bomID, tenantID uuid.UUID, req *prodmodels.UpdateBOMRequest, userID uuid.UUID) error {
	var status string

	err := r.db.QueryRow(ctx, `
		SELECT status
		FROM bom_headers
		WHERE bom_id = $1 AND tenant_id = $2
	`, bomID, tenantID).Scan(&status)
	if err != nil {
		return fmt.Errorf("get bom status: %w", err)
	}

	if status == "ACTIVE" {
		return fmt.Errorf("409_BOM_ACTIVE: cannot update an ACTIVE BOM")
	}

	parseTime := func(s *string) *time.Time {
		if s == nil || *s == "" {
			return nil
		}

		t, err := parseTimeFlexible(*s)
		if err != nil {
			return nil
		}

		return &t
	}

	validFrom := parseTime(req.ValidFrom)
	validTo := parseTime(req.ValidTo)

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		UPDATE bom_headers SET
			bom_version        = COALESCE($3, bom_version),
			bom_usage          = COALESCE($4, bom_usage),
			base_qty           = COALESCE($5, base_qty),
			valid_from         = COALESCE($6, valid_from),
			valid_to           = COALESCE($7, valid_to),
			description        = COALESCE($8, description),
			is_active          = COALESCE($9, is_active),
			routing_template_id = COALESCE($10, routing_template_id),
			updated_by         = $11,
			updated_at         = NOW()
		WHERE bom_id = $1 AND tenant_id = $2
	`, bomID, tenantID,
		req.BOMVersion,
		req.BOMUsage,
		req.BaseQty,
		validFrom,
		validTo,
		req.Description,
		req.IsActive,
		req.RoutingTemplateID,
		&userID,
	)
	if err != nil {
		return fmt.Errorf("update bom_header: %w", err)
	}

	if req.Items != nil {
		keepIDs := map[uuid.UUID]bool{}

		for i, itemReq := range req.Items {
			if itemReq.ComponentID == uuid.Nil {
				return fmt.Errorf("component_id is required at item index %d", i)
			}

			if itemReq.Quantity <= 0 {
				return fmt.Errorf("quantity must be > 0 for component %s", itemReq.ComponentID)
			}

			if itemReq.ItemPosition <= 0 {
				itemReq.ItemPosition = (i + 1) * 10
			}

			if itemReq.UnitOfMeasure == "" {
				itemReq.UnitOfMeasure = "EA"
			}

			if itemReq.ItemID != uuid.Nil {
				tag, err := tx.Exec(ctx, `
					UPDATE bom_items SET
						item_position   = $2,
						component_id     = $3,
						quantity         = $4,
						unit_of_measure  = $5,
						scrap_factor     = $6,
						is_phantom_item  = $7,
						remark           = $8,
						updated_at       = NOW()
					WHERE item_id = $1 AND bom_id = $9
				`,
					itemReq.ItemID,
					itemReq.ItemPosition,
					itemReq.ComponentID,
					itemReq.Quantity,
					itemReq.UnitOfMeasure,
					itemReq.ScrapFactor,
					itemReq.IsPhantomItem,
					nullIfEmpty(itemReq.Remark),
					bomID,
				)
				if err != nil {
					return fmt.Errorf("update bom_item: %w", err)
				}

				if tag.RowsAffected() == 0 {
					return fmt.Errorf("bom_item not found or not belong to bom: %s", itemReq.ItemID)
				}

				keepIDs[itemReq.ItemID] = true
			} else {
				item, err := r.insertItemTx(ctx, tx, bomID, &itemReq)
				if err != nil {
					return err
				}

				keepIDs[item.ItemID] = true
			}
		}

		rows, err := tx.Query(ctx, `
			SELECT item_id
			FROM bom_items
			WHERE bom_id = $1
		`, bomID)
		if err != nil {
			return fmt.Errorf("load existing bom_items: %w", err)
		}

		var deleteIDs []uuid.UUID

		for rows.Next() {
			var existingID uuid.UUID

			if err := rows.Scan(&existingID); err != nil {
				rows.Close()
				return err
			}

			if !keepIDs[existingID] {
				deleteIDs = append(deleteIDs, existingID)
			}
		}

		rows.Close()

		for _, deleteID := range deleteIDs {
			_, err = tx.Exec(ctx, `
				DELETE FROM bom_items
				WHERE item_id = $1 AND bom_id = $2
			`, deleteID, bomID)
			if err != nil {
				return fmt.Errorf("delete bom_item: %w", err)
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

// Delete performs a soft delete: sets status='INACTIVE' and valid_to=NOW().
// Blocks if this BOM's material_id is used as component_id in any ACTIVE BOM.
func (r *BOMRepo) Delete(ctx context.Context, bomID, tenantID uuid.UUID, userID uuid.UUID) error {
	// Get material_id of this BOM
	var materialID uuid.UUID
	err := r.db.QueryRow(ctx, `SELECT material_id FROM bom_headers WHERE bom_id = $1 AND tenant_id = $2`, bomID, tenantID).Scan(&materialID)
	if err != nil {
		return fmt.Errorf("get bom material_id: %w", err)
	}

	// Check if this material is used as a component in any ACTIVE BOM (across all BOMs, same tenant)
	var refCount int
	err = r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM bom_items bi
		JOIN bom_headers bh ON bh.bom_id = bi.bom_id
		WHERE bi.component_id = $1 AND bh.tenant_id = $2 AND bh.status = 'ACTIVE'
	`, materialID, tenantID).Scan(&refCount)
	if err != nil {
		return fmt.Errorf("check component reference: %w", err)
	}
	if refCount > 0 {
		return fmt.Errorf("409_BOM_IN_USE: material is used as component in %d ACTIVE BOM(s)", refCount)
	}

	now := time.Now()
	_, err = r.db.Exec(ctx, `
		UPDATE bom_headers SET
			status = 'INACTIVE',
			valid_to = $3,
			updated_by = $4,
			updated_at = NOW()
		WHERE bom_id = $1 AND tenant_id = $2
	`, bomID, tenantID, now, &userID)
	return err
}

// ─────────────────────────────────────────────────────────────────
// BOM Item CRUD (individual items)
// ─────────────────────────────────────────────────────────────────

// AddItem adds a new item to an existing BOM.
func (r *BOMRepo) AddItem(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateBOMItemRequest) (*prodmodels.BOMItem, error) {
	// Verify BOM exists and belongs to tenant
	var status string
	err := r.db.QueryRow(ctx, `SELECT status FROM bom_headers WHERE bom_id = $1 AND tenant_id = $2`, req.BOMID, tenantID).Scan(&status)
	if err != nil {
		return nil, fmt.Errorf("bom not found: %w", err)
	}
	if status == "ACTIVE" {
		return nil, fmt.Errorf("409_BOM_ACTIVE: cannot modify an ACTIVE BOM")
	}

	// Auto-assign item_position if not provided
	if req.ItemPosition <= 0 {
		var maxPos int
		err := r.db.QueryRow(ctx, `SELECT COALESCE(MAX(item_position),0) FROM bom_items WHERE bom_id = $1`, req.BOMID).Scan(&maxPos)
		if err != nil {
			return nil, err
		}
		req.ItemPosition = maxPos + 10
	}

	item := &prodmodels.BOMItem{
		ItemID:        uuid.New(),
		BOMID:         req.BOMID,
		ItemPosition:  req.ItemPosition,
		ComponentID:   req.ComponentID,
		Quantity:      req.Quantity,
		UnitOfMeasure: req.UnitOfMeasure,
		ScrapFactor:   req.ScrapFactor,
		IsPhantomItem: req.IsPhantomItem,
		Remark:        req.Remark,
	}

	if item.UnitOfMeasure == "" {
		item.UnitOfMeasure = "EA"
	}

	_, err = r.db.Exec(ctx, `
		INSERT INTO bom_items (item_id, bom_id, item_position, component_id, quantity,
			unit_of_measure, scrap_factor, is_phantom_item, remark, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),NOW())
	`, item.ItemID, item.BOMID, item.ItemPosition, item.ComponentID, item.Quantity,
		item.UnitOfMeasure, item.ScrapFactor, item.IsPhantomItem, nullIfEmpty(item.Remark))
	if err != nil {
		return nil, fmt.Errorf("insert bom_item: %w", err)
	}

	r.enrichComponent(ctx, item)
	return item, nil
}

// UpdateItem modifies a BOM item.
func (r *BOMRepo) UpdateItem(ctx context.Context, itemID, tenantID uuid.UUID, req *prodmodels.UpdateBOMItemRequest) error {
	// Verify the item's BOM is not ACTIVE
	var bomID uuid.UUID
	var status string
	err := r.db.QueryRow(ctx, `
		SELECT bi.bom_id, bh.status
		FROM bom_items bi
		JOIN bom_headers bh ON bh.bom_id = bi.bom_id
		WHERE bi.item_id = $1 AND bh.tenant_id = $2
	`, itemID, tenantID).Scan(&bomID, &status)
	if err != nil {
		return fmt.Errorf("item not found: %w", err)
	}
	if status == "ACTIVE" {
		return fmt.Errorf("409_BOM_ACTIVE: cannot modify an ACTIVE BOM")
	}

	_, err = r.db.Exec(ctx, `
		UPDATE bom_items SET
			item_position  = COALESCE($2, item_position),
			component_id   = COALESCE($3, component_id),
			quantity       = COALESCE($4, quantity),
			unit_of_measure = COALESCE($5, unit_of_measure),
			scrap_factor   = COALESCE($6, scrap_factor),
			is_phantom_item = COALESCE($7, is_phantom_item),
			remark         = COALESCE($8, remark),
			updated_at     = NOW()
		WHERE item_id = $1
	`, itemID,
		req.ItemPosition, req.ComponentID, req.Quantity,
		req.UnitOfMeasure, req.ScrapFactor, req.IsPhantomItem, req.Remark)
	return err
}

// DeleteItem removes a BOM item.
func (r *BOMRepo) DeleteItem(ctx context.Context, itemID, tenantID uuid.UUID) error {
	// Verify the item's BOM is not ACTIVE
	var status string
	err := r.db.QueryRow(ctx, `
		SELECT bh.status
		FROM bom_items bi
		JOIN bom_headers bh ON bh.bom_id = bi.bom_id
		WHERE bi.item_id = $1 AND bh.tenant_id = $2
	`, itemID, tenantID).Scan(&status)
	if err != nil {
		return fmt.Errorf("item not found: %w", err)
	}
	if status == "ACTIVE" {
		return fmt.Errorf("409_BOM_ACTIVE: cannot modify an ACTIVE BOM")
	}

	_, err = r.db.Exec(ctx, `DELETE FROM bom_items WHERE item_id = $1`, itemID)
	return err
}

// ─────────────────────────────────────────────────────────────────
// BOM Explosion (FSD §4.2)
// ─────────────────────────────────────────────────────────────────

// Explode performs single-level or multi-level BOM explosion.
func (r *BOMRepo) Explode(ctx context.Context, tenantID uuid.UUID, req *prodmodels.ExplodeRequest) ([]*prodmodels.ExplosionItem, error) {
	// Find the BOM version (or the latest ACTIVE one)
	bomID, err := r.findBOMID(ctx, tenantID, req.MaterialID, req.BOMVersion)
	if err != nil {
		return nil, err
	}
	if bomID == uuid.Nil {
		return nil, fmt.Errorf("404_BOM_NOT_FOUND: no active BOM for material")
	}

	baseQty := req.RequirementQty
	if baseQty <= 0 {
		baseQty = 1
	}

	if req.ExplosionType == "single" {
		return r.explodeSingle(ctx, tenantID, bomID, baseQty)
	}
	return r.explodeMulti(ctx, tenantID, bomID, baseQty, 1, make(map[uuid.UUID]bool))
}

// findBOMID looks up the BOM for a given material+version, falling back to the latest ACTIVE.
func (r *BOMRepo) findBOMID(ctx context.Context, tenantID, materialID uuid.UUID, bomVersion string) (uuid.UUID, error) {
	if bomVersion != "" {
		var bomID uuid.UUID
		err := r.db.QueryRow(ctx, `
			SELECT bom_id FROM bom_headers
			WHERE tenant_id = $1 AND material_id = $2 AND bom_version = $3 AND status = 'ACTIVE'
		`, tenantID, materialID, bomVersion).Scan(&bomID)
		if err == nil {
			return bomID, nil
		}
		if err != pgx.ErrNoRows {
			return uuid.Nil, err
		}
	}

	// Fallback: latest ACTIVE by created_at
	var bomID uuid.UUID
	err := r.db.QueryRow(ctx, `
		SELECT bom_id FROM bom_headers
		WHERE tenant_id = $1 AND material_id = $2 AND status = 'ACTIVE'
		ORDER BY created_at DESC LIMIT 1
	`, tenantID, materialID).Scan(&bomID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return uuid.Nil, nil
		}
		return uuid.Nil, err
	}
	return bomID, nil
}

// explodeSingle returns the direct components with quantities scaled to requirement_qty.
func (r *BOMRepo) explodeSingle(ctx context.Context, tenantID, bomID uuid.UUID, baseQty float64) ([]*prodmodels.ExplosionItem, error) {
	rows, err := r.db.Query(ctx, `
		SELECT bi.component_id, COALESCE(p.name,''), COALESCE(p.sku,''),
			bi.quantity, bi.unit_of_measure, bi.scrap_factor, bi.is_phantom_item,
			COALESCE(bh.bom_version,'')
		FROM bom_items bi
		JOIN bom_headers bh ON bh.bom_id = bi.bom_id
		LEFT JOIN products p ON p.id = bi.component_id
		WHERE bi.bom_id = $1 AND bh.tenant_id = $2
		ORDER BY bi.item_position
	`, bomID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("explode single: %w", err)
	}
	defer rows.Close()

	var list []*prodmodels.ExplosionItem
	for rows.Next() {
		ei := &prodmodels.ExplosionItem{Level: 1}
		if err := rows.Scan(
			&ei.ComponentID, &ei.ComponentName, &ei.ComponentSKU,
			&ei.Quantity, &ei.UnitOfMeasure, &ei.ScrapFactor, &ei.IsPhantomItem,
			&ei.BOMVersion,
		); err != nil {
			return nil, err
		}
		// actual_qty = baseQty * component_qty / (1 - scrap_factor)
		ei.Quantity = baseQty * ei.Quantity / (1 - ei.ScrapFactor)
		list = append(list, ei)
	}
	return list, nil
}

// explodeMulti recursively flattens all levels.
func (r *BOMRepo) explodeMulti(ctx context.Context, tenantID, bomID uuid.UUID, parentQty float64, level int, visited map[uuid.UUID]bool) ([]*prodmodels.ExplosionItem, error) {
	rows, err := r.db.Query(ctx, `
		SELECT bi.component_id, COALESCE(p.name,''), COALESCE(p.sku,''),
			bi.quantity, bi.unit_of_measure, bi.scrap_factor, bi.is_phantom_item,
			COALESCE(bh.bom_version,'')
		FROM bom_items bi
		JOIN bom_headers bh ON bh.bom_id = bi.bom_id
		LEFT JOIN products p ON p.id = bi.component_id
		WHERE bi.bom_id = $1 AND bh.tenant_id = $2
		ORDER BY bi.item_position
	`, bomID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("explode multi: %w", err)
	}
	defer rows.Close()

	var results []*prodmodels.ExplosionItem
	for rows.Next() {
		ei := &prodmodels.ExplosionItem{Level: level}
		var bOMVersion string
		if err := rows.Scan(
			&ei.ComponentID, &ei.ComponentName, &ei.ComponentSKU,
			&ei.Quantity, &ei.UnitOfMeasure, &ei.ScrapFactor, &ei.IsPhantomItem,
			&bOMVersion,
		); err != nil {
			return nil, err
		}
		ei.BOMVersion = bOMVersion

		// actual_qty = (parent_qty * component_qty) / (1 - scrap_factor)
		ei.Quantity = parentQty * ei.Quantity / (1 - ei.ScrapFactor)
		results = append(results, ei)

		// If this component has its own BOM, recurse (avoid infinite loops)
		if !visited[ei.ComponentID] {
			childBOMID, err := r.findBOMID(ctx, tenantID, ei.ComponentID, "")
			if err != nil {
				continue
			}
			if childBOMID != uuid.Nil {
				visited[ei.ComponentID] = true
				children, err := r.explodeMulti(ctx, tenantID, childBOMID, ei.Quantity, level+1, visited)
				if err != nil {
					return nil, err
				}
				results = append(results, children...)
			}
		}
	}
	return results, nil
}

// ─────────────────────────────────────────────────────────────────
// Anti-loop check (FSD §4.1)
// ─────────────────────────────────────────────────────────────────

// checkAntiLoop builds a directed graph and DFS-es each component's existing BOMs.
// If any child's material_id == parent material_id, return an error.
func (r *BOMRepo) checkAntiLoop(ctx context.Context, tenantID, parentMaterialID uuid.UUID, items []prodmodels.CreateBOMItemRequest) error {
	// Step 1: Check immediate self-reference (component == parent material)
	for _, item := range items {
		if item.ComponentID == parentMaterialID {
			return fmt.Errorf("409_BOM_LOOP_DETECTED: component %s directly references its own parent material %s", item.ComponentID, parentMaterialID)
		}
	}

	// Step 2: Build the set of component IDs from the request
	componentIDs := make([]uuid.UUID, len(items))
	for i, item := range items {
		componentIDs[i] = item.ComponentID
	}

	// Step 3: DFS each component's existing BOMs for transitive loops
	visited := make(map[uuid.UUID]bool)
	for _, compID := range componentIDs {
		if err := r.dfsAntiLoop(ctx, tenantID, parentMaterialID, compID, visited); err != nil {
			return err
		}
	}
	return nil
}

func (r *BOMRepo) dfsAntiLoop(ctx context.Context, tenantID, targetMaterialID, currentID uuid.UUID, visited map[uuid.UUID]bool) error {
	if visited[currentID] {
		return nil
	}
	visited[currentID] = true

	// Get ACTIVE BOMs where currentID is the material (parent)
	rows, err := r.db.Query(ctx, `
		SELECT bi.component_id
		FROM bom_items bi
		JOIN bom_headers bh ON bh.bom_id = bi.bom_id
		WHERE bh.material_id = $1 AND bh.tenant_id = $2 AND bh.status = 'ACTIVE'
	`, currentID, tenantID)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var childID uuid.UUID
		if err := rows.Scan(&childID); err != nil {
			return err
		}
		if childID == targetMaterialID {
			return fmt.Errorf("409_BOM_LOOP_DETECTED: material %s would create a circular reference", targetMaterialID)
		}
		if err := r.dfsAntiLoop(ctx, tenantID, targetMaterialID, childID, visited); err != nil {
			return err
		}
	}
	return nil
}

// ─────────────────────────────────────────────────────────────────
// Item helpers
// ─────────────────────────────────────────────────────────────────

func (r *BOMRepo) insertItemTx(ctx context.Context, tx pgx.Tx, bomID uuid.UUID, req *prodmodels.CreateBOMItemRequest) (*prodmodels.BOMItem, error) {
	pos := req.ItemPosition
	if pos <= 0 {
		var maxPos int
		err := tx.QueryRow(ctx, `SELECT COALESCE(MAX(item_position),0) FROM bom_items WHERE bom_id = $1`, bomID).Scan(&maxPos)
		if err != nil {
			return nil, err
		}
		pos = maxPos + 10
	}

	qty := req.Quantity
	if qty <= 0 {
		return nil, fmt.Errorf("quantity must be > 0 for component %s", req.ComponentID)
	}

	uom := req.UnitOfMeasure
	if uom == "" {
		uom = "EA"
	}

	item := &prodmodels.BOMItem{
		ItemID:        uuid.New(),
		BOMID:         bomID,
		ItemPosition:  pos,
		ComponentID:   req.ComponentID,
		Quantity:      qty,
		UnitOfMeasure: uom,
		ScrapFactor:   req.ScrapFactor,
		IsPhantomItem: req.IsPhantomItem,
		Remark:        req.Remark,
	}

	_, err := tx.Exec(ctx, `
		INSERT INTO bom_items (item_id, bom_id, item_position, component_id, quantity,
			unit_of_measure, scrap_factor, is_phantom_item, remark, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),NOW())
	`, item.ItemID, item.BOMID, item.ItemPosition, item.ComponentID, item.Quantity,
		item.UnitOfMeasure, item.ScrapFactor, item.IsPhantomItem, nullIfEmpty(item.Remark))
	if err != nil {
		return nil, fmt.Errorf("insert bom_item: %w", err)
	}

	return item, nil
}

func (r *BOMRepo) loadItems(ctx context.Context, bomID, tenantID uuid.UUID) ([]prodmodels.BOMItem, error) {
	rows, err := r.db.Query(ctx, `
		SELECT bi.item_id, bi.bom_id, bi.item_position,
			bi.component_id, COALESCE(p.name,''), COALESCE(p.sku,''),
			bi.quantity, bi.unit_of_measure, bi.scrap_factor, bi.is_phantom_item,
			bi.valid_from, bi.valid_to, COALESCE(bi.remark,''),
			bi.created_at, bi.updated_at
		FROM bom_items bi
		LEFT JOIN products p ON p.id = bi.component_id
		WHERE bi.bom_id = $1
		ORDER BY bi.item_position
	`, bomID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []prodmodels.BOMItem
	for rows.Next() {
		item := prodmodels.BOMItem{}
		if err := rows.Scan(
			&item.ItemID, &item.BOMID, &item.ItemPosition,
			&item.ComponentID, &item.ComponentName, &item.ComponentSKU,
			&item.Quantity, &item.UnitOfMeasure, &item.ScrapFactor, &item.IsPhantomItem,
			&item.ValidFrom, &item.ValidTo, &item.Remark,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, item)
	}
	return list, nil
}

func (r *BOMRepo) enrichMaterial(ctx context.Context, h *prodmodels.BOMHeader) {
	_ = r.db.QueryRow(ctx, `SELECT COALESCE(name,''), COALESCE(sku,'') FROM products WHERE id = $1`,
		h.MaterialID).Scan(&h.MaterialName, &h.MaterialSKU)
}

func (r *BOMRepo) enrichComponent(ctx context.Context, item *prodmodels.BOMItem) {
	_ = r.db.QueryRow(ctx, `SELECT COALESCE(name,''), COALESCE(sku,'') FROM products WHERE id = $1`,
		item.ComponentID).Scan(&item.ComponentName, &item.ComponentSKU)
}

// ─────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════
// WorkCenterRepo
// ═══════════════════════════════════════════════════════════════

type WorkCenterRepo struct {
	db *pgxpool.Pool
}

func NewWorkCenterRepo(db *pgxpool.Pool) *WorkCenterRepo {
	return &WorkCenterRepo{db: db}
}

func (r *WorkCenterRepo) Create(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateWorkCenterRequest) (*prodmodels.WorkCenter, error) {
	wc := &prodmodels.WorkCenter{
		ID:                uuid.New(),
		TenantID:          tenantID,
		Code:              req.Code,
		Name:              req.Name,
		Description:       req.Description,
		WorkCenterType:    req.WorkCenterType,
		AvailableCapacity: req.AvailableCapacity,
		EfficiencyRate:    req.EfficiencyRate,
		CostPerHour:       req.CostPerHour,
		PlantLocation:     req.PlantLocation,
		IsActive:          true,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}
	if wc.WorkCenterType == "" {
		wc.WorkCenterType = "machine"
	}
	if wc.AvailableCapacity <= 0 {
		wc.AvailableCapacity = 8.00
	}
	if wc.EfficiencyRate <= 0 {
		wc.EfficiencyRate = 1.00
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO work_centers (id, tenant_id, code, name, description, work_center_type,
			available_capacity, efficiency_rate, cost_per_hour, plant_location, is_active, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,NOW(),NOW())
	`, wc.ID, wc.TenantID, wc.Code, wc.Name, wc.Description, wc.WorkCenterType,
		wc.AvailableCapacity, wc.EfficiencyRate, wc.CostPerHour, wc.PlantLocation, wc.IsActive)
	if err != nil {
		return nil, fmt.Errorf("insert work center: %w", err)
	}
	return wc, nil
}

func (r *WorkCenterRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.WorkCenter, error) {
	wc := &prodmodels.WorkCenter{}
	err := r.db.QueryRow(ctx, `
		SELECT id, tenant_id, code, name, COALESCE(description,''), work_center_type,
			available_capacity, efficiency_rate, cost_per_hour, COALESCE(plant_location,''),
			is_active, created_at, updated_at
		FROM work_centers WHERE id = $1 AND tenant_id = $2
	`, id, tenantID).Scan(
		&wc.ID, &wc.TenantID, &wc.Code, &wc.Name, &wc.Description, &wc.WorkCenterType,
		&wc.AvailableCapacity, &wc.EfficiencyRate, &wc.CostPerHour, &wc.PlantLocation,
		&wc.IsActive, &wc.CreatedAt, &wc.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get work center: %w", err)
	}
	return wc, nil
}

func (r *WorkCenterRepo) List(ctx context.Context, tenantID uuid.UUID) ([]*prodmodels.WorkCenter, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, code, name, COALESCE(description,''), work_center_type,
			available_capacity, efficiency_rate, cost_per_hour, COALESCE(plant_location,''),
			is_active, created_at, updated_at
		FROM work_centers WHERE tenant_id = $1 ORDER BY code
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*prodmodels.WorkCenter
	for rows.Next() {
		wc := &prodmodels.WorkCenter{}
		if err := rows.Scan(&wc.ID, &wc.TenantID, &wc.Code, &wc.Name, &wc.Description, &wc.WorkCenterType,
			&wc.AvailableCapacity, &wc.EfficiencyRate, &wc.CostPerHour, &wc.PlantLocation,
			&wc.IsActive, &wc.CreatedAt, &wc.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, wc)
	}
	return list, nil
}

func (r *WorkCenterRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateWorkCenterRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE work_centers SET
			code              = COALESCE($3, code),
			name              = COALESCE($4, name),
			description       = COALESCE($5, description),
			work_center_type  = COALESCE($6, work_center_type),
			available_capacity = COALESCE($7, available_capacity),
			efficiency_rate   = COALESCE($8, efficiency_rate),
			cost_per_hour     = COALESCE($9, cost_per_hour),
			plant_location    = COALESCE($10, plant_location),
			is_active         = COALESCE($11, is_active),
			updated_at        = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.Code, req.Name, req.Description, req.WorkCenterType,
		req.AvailableCapacity, req.EfficiencyRate, req.CostPerHour, req.PlantLocation, req.IsActive)
	return err
}

func (r *WorkCenterRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM work_centers WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	return err
}

// ═══════════════════════════════════════════════════════════════
// RoutingTemplateRepo
// ═══════════════════════════════════════════════════════════════

type RoutingTemplateRepo struct {
	db *pgxpool.Pool
}

func NewRoutingTemplateRepo(db *pgxpool.Pool) *RoutingTemplateRepo {
	return &RoutingTemplateRepo{db: db}
}

func (r *RoutingTemplateRepo) Create(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateRoutingTemplateRequest) (*prodmodels.RoutingTemplate, error) {
	rt := &prodmodels.RoutingTemplate{
		ID:           uuid.New(),
		TenantID:     tenantID,
		TemplateCode: req.TemplateCode,
		TemplateName: req.TemplateName,
		Description:  req.Description,
		Version:      req.Version,
		Status:       "ACTIVE",
		IsActive:     true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
	if rt.Version == "" {
		rt.Version = "V1"
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO routing_templates (id, tenant_id, template_code, template_name, description,
			version, status, total_setup_min, total_run_min, is_active, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,0,0,$8,NOW(),NOW())
	`, rt.ID, rt.TenantID, rt.TemplateCode, rt.TemplateName, rt.Description, rt.Version, rt.Status, rt.IsActive)
	if err != nil {
		return nil, fmt.Errorf("insert routing template: %w", err)
	}
	return rt, nil
}

func (r *RoutingTemplateRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.RoutingTemplate, error) {
	rt := &prodmodels.RoutingTemplate{}
	err := r.db.QueryRow(ctx, `
		SELECT rt.id, rt.tenant_id, rt.template_code, rt.template_name, COALESCE(rt.description,''),
			rt.version, rt.status, rt.total_setup_min, rt.total_run_min, rt.is_active, rt.created_at, rt.updated_at
		FROM routing_templates rt
		WHERE rt.id = $1 AND rt.tenant_id = $2
	`, id, tenantID).Scan(
		&rt.ID, &rt.TenantID, &rt.TemplateCode, &rt.TemplateName, &rt.Description,
		&rt.Version, &rt.Status, &rt.TotalSetupMin, &rt.TotalRunMin,
		&rt.IsActive, &rt.CreatedAt, &rt.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get routing template: %w", err)
	}
	// Load operations
	ops, err := r.loadOperations(ctx, id, tenantID)
	if err == nil {
		rt.Operations = ops
	}
	return rt, nil
}

func (r *RoutingTemplateRepo) List(ctx context.Context, tenantID uuid.UUID) ([]*prodmodels.RoutingTemplate, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, template_code, template_name, COALESCE(description,''),
			version, status, total_setup_min, total_run_min, is_active, created_at, updated_at
		FROM routing_templates WHERE tenant_id = $1 ORDER BY template_code
	`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*prodmodels.RoutingTemplate
	for rows.Next() {
		rt := &prodmodels.RoutingTemplate{}
		if err := rows.Scan(&rt.ID, &rt.TenantID, &rt.TemplateCode, &rt.TemplateName, &rt.Description,
			&rt.Version, &rt.Status, &rt.TotalSetupMin, &rt.TotalRunMin,
			&rt.IsActive, &rt.CreatedAt, &rt.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, rt)
	}
	return list, nil
}

func (r *RoutingTemplateRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateRoutingTemplateRequest) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		UPDATE routing_templates SET
			template_code = COALESCE($3, template_code),
			template_name = COALESCE($4, template_name),
			description   = COALESCE($5, description),
			version       = COALESCE($6, version),
			status        = COALESCE($7, status),
			is_active     = COALESCE($8, is_active),
			updated_at    = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID,
		req.TemplateCode,
		req.TemplateName,
		req.Description,
		req.Version,
		req.Status,
		req.IsActive,
	)
	if err != nil {
		return fmt.Errorf("update routing_template: %w", err)
	}

	if req.Operations != nil {
		keepIDs := map[uuid.UUID]bool{}

		for i, opReq := range req.Operations {
			if opReq.OperationNo <= 0 {
				opReq.OperationNo = (i + 1) * 10
			}

			if opReq.OperationName == "" {
				return fmt.Errorf("operation_name is required at index %d", i)
			}

			if opReq.WorkCenterID == uuid.Nil {
				return fmt.Errorf("work_center_id is required at index %d", i)
			}

			if opReq.ID != uuid.Nil {
				tag, err := tx.Exec(ctx, `
					UPDATE template_operations SET
						operation_no   = $3,
						operation_name = $4,
						description    = $5,
						work_center_id = $6,
						setup_time_min = $7,
						run_time_min   = $8,
						is_active      = true,
						updated_at     = NOW()
					WHERE id = $1 AND tenant_id = $2 AND template_id = $9
				`,
					opReq.ID,
					tenantID,
					opReq.OperationNo,
					opReq.OperationName,
					nullIfEmpty(opReq.Description),
					opReq.WorkCenterID,
					opReq.SetupTimeMin,
					opReq.RunTimeMin,
					id,
				)
				if err != nil {
					return fmt.Errorf("update template_operation: %w", err)
				}

				if tag.RowsAffected() == 0 {
					return fmt.Errorf("template_operation not found or not belong to template: %s", opReq.ID)
				}

				keepIDs[opReq.ID] = true
			} else {
				newID := uuid.New()

				_, err := tx.Exec(ctx, `
					INSERT INTO template_operations (
						id, tenant_id, template_id, operation_no, operation_name,
						description, work_center_id, setup_time_min, run_time_min,
						is_active, created_at, updated_at
					)
					VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,true,NOW(),NOW())
				`,
					newID,
					tenantID,
					id,
					opReq.OperationNo,
					opReq.OperationName,
					nullIfEmpty(opReq.Description),
					opReq.WorkCenterID,
					opReq.SetupTimeMin,
					opReq.RunTimeMin,
				)
				if err != nil {
					return fmt.Errorf("insert template_operation: %w", err)
				}

				keepIDs[newID] = true
			}
		}

		rows, err := tx.Query(ctx, `
			SELECT id
			FROM template_operations
			WHERE template_id = $1 AND tenant_id = $2
		`, id, tenantID)
		if err != nil {
			return fmt.Errorf("load existing template_operations: %w", err)
		}

		var deleteIDs []uuid.UUID

		for rows.Next() {
			var existingID uuid.UUID
			if err := rows.Scan(&existingID); err != nil {
				rows.Close()
				return err
			}

			if !keepIDs[existingID] {
				deleteIDs = append(deleteIDs, existingID)
			}
		}
		rows.Close()

		for _, deleteID := range deleteIDs {
			_, err = tx.Exec(ctx, `
				DELETE FROM template_operations
				WHERE id = $1 AND tenant_id = $2 AND template_id = $3
			`, deleteID, tenantID, id)
			if err != nil {
				return fmt.Errorf("delete template_operation: %w", err)
			}
		}
	}

	_, err = tx.Exec(ctx, `
		UPDATE routing_templates SET
			total_setup_min = (
				SELECT COALESCE(SUM(setup_time_min),0)
				FROM template_operations
				WHERE template_id = $1 AND tenant_id = $2 AND is_active = true
			),
			total_run_min = (
				SELECT COALESCE(SUM(run_time_min),0)
				FROM template_operations
				WHERE template_id = $1 AND tenant_id = $2 AND is_active = true
			),
			updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID)
	if err != nil {
		return fmt.Errorf("recalculate template totals: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	return nil
}

func (r *RoutingTemplateRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM routing_templates WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	return err
}

func (r *RoutingTemplateRepo) RecalculateTotals(ctx context.Context, templateID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE routing_templates SET
			total_setup_min = (SELECT COALESCE(SUM(setup_time_min),0) FROM template_operations WHERE template_id = $1 AND is_active = true),
			total_run_min   = (SELECT COALESCE(SUM(run_time_min),0) FROM template_operations WHERE template_id = $1 AND is_active = true)
		WHERE id = $1
	`, templateID)
	return err
}

func (r *RoutingTemplateRepo) loadOperations(ctx context.Context, templateID, tenantID uuid.UUID) ([]prodmodels.TemplateOperation, error) {
	rows, err := r.db.Query(ctx, `
		SELECT o.id, o.tenant_id, o.template_id, o.operation_no, o.operation_name,
			COALESCE(o.description,''), o.work_center_id, COALESCE(wc.name,''), COALESCE(wc.code,''),
			o.setup_time_min, o.run_time_min, o.is_active, o.created_at, o.updated_at
		FROM template_operations o
		LEFT JOIN work_centers wc ON wc.id = o.work_center_id
		WHERE o.template_id = $1 AND o.tenant_id = $2 AND o.is_active = true
		ORDER BY o.operation_no
	`, templateID, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ops []prodmodels.TemplateOperation
	for rows.Next() {
		op := prodmodels.TemplateOperation{}
		if err := rows.Scan(&op.ID, &op.TenantID, &op.TemplateID, &op.OperationNo, &op.OperationName,
			&op.Description, &op.WorkCenterID, &op.WorkCenterName, &op.WorkCenterCode,
			&op.SetupTimeMin, &op.RunTimeMin, &op.IsActive, &op.CreatedAt, &op.UpdatedAt); err != nil {
			return nil, err
		}
		ops = append(ops, op)
	}
	return ops, nil
}

// ═══════════════════════════════════════════════════════════════
// TemplateOperationRepo
// ═══════════════════════════════════════════════════════════════

type TemplateOperationRepo struct {
	db *pgxpool.Pool
}

func NewTemplateOperationRepo(db *pgxpool.Pool) *TemplateOperationRepo {
	return &TemplateOperationRepo{db: db}
}

func (r *TemplateOperationRepo) Create(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateTemplateOperationRequest) (*prodmodels.TemplateOperation, error) {
	if req.OperationNo <= 0 {
		var maxNo int
		err := r.db.QueryRow(ctx, `SELECT COALESCE(MAX(operation_no),0) FROM template_operations WHERE template_id = $1`, req.TemplateID).Scan(&maxNo)
		if err == nil {
			req.OperationNo = maxNo + 10
		}
	}

	op := &prodmodels.TemplateOperation{
		ID:            uuid.New(),
		TenantID:      tenantID,
		TemplateID:    req.TemplateID,
		OperationNo:   req.OperationNo,
		OperationName: req.OperationName,
		Description:   req.Description,
		WorkCenterID:  req.WorkCenterID,
		SetupTimeMin:  req.SetupTimeMin,
		RunTimeMin:    req.RunTimeMin,
		IsActive:      true,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO template_operations (id, tenant_id, template_id, operation_no, operation_name,
			description, work_center_id, setup_time_min, run_time_min, is_active, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW(),NOW())
	`, op.ID, op.TenantID, op.TemplateID, op.OperationNo, op.OperationName, op.Description,
		op.WorkCenterID, op.SetupTimeMin, op.RunTimeMin, op.IsActive)
	if err != nil {
		return nil, fmt.Errorf("insert template operation: %w", err)
	}

	// Recalculate template totals
	rtRepo := &RoutingTemplateRepo{db: r.db}
	_ = rtRepo.RecalculateTotals(ctx, req.TemplateID)

	return op, nil
}

func (r *TemplateOperationRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateTemplateOperationRequest) error {
	_, err := r.db.Exec(ctx, `
		UPDATE template_operations SET
			operation_no   = COALESCE($3, operation_no),
			operation_name = COALESCE($4, operation_name),
			description    = COALESCE($5, description),
			work_center_id = COALESCE($6, work_center_id),
			setup_time_min = COALESCE($7, setup_time_min),
			run_time_min   = COALESCE($8, run_time_min),
			is_active      = COALESCE($9, is_active),
			updated_at     = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.OperationNo, req.OperationName, req.Description,
		req.WorkCenterID, req.SetupTimeMin, req.RunTimeMin, req.IsActive)
	return err
}

func (r *TemplateOperationRepo) Delete(ctx context.Context, id, tenantID uuid.UUID) error {
	var templateID uuid.UUID
	err := r.db.QueryRow(ctx, `SELECT template_id FROM template_operations WHERE id = $1 AND tenant_id = $2`, id, tenantID).Scan(&templateID)
	if err != nil {
		return fmt.Errorf("operation not found: %w", err)
	}

	_, err = r.db.Exec(ctx, `DELETE FROM template_operations WHERE id = $1 AND tenant_id = $2`, id, tenantID)
	if err != nil {
		return err
	}

	// Recalculate template totals
	rtRepo := &RoutingTemplateRepo{db: r.db}
	return rtRepo.RecalculateTotals(ctx, templateID)
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// parseTimeFlexible parses ISO 8601 timestamps with or without timezone.
// Valid formats:
//   - 2026-06-11T21:40:00.000Z       (with Z suffix)
//   - 2026-06-11T21:40:00.000+08:00 (with offset)
//   - 2026-06-11T21:40:00.000       (no timezone, treated as UTC)
//   - 2026-06-11T21:40:00Z          (no fractional seconds)
//   - 2026-06-11                    (date only)
func parseTimeFlexible(s string) (time.Time, error) {
	formats := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02",
		"2006-01-02T15:04:05.000Z07:00",
		"2006-01-02T15:04:05.000",
		"2006-01-02T15:04:05",
		"2006-01-02T15:04:05.000Z",
		"2006-01-02T15:04:05Z",
	}
	for _, f := range formats {
		t, err := time.Parse(f, s)
		if err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("cannot parse time: %s", s)
}

// ---------------------------------------------------------------
// ProductionOrderRepo
// ---------------------------------------------------------------

type ProductionOrderRepo struct {
	db *pgxpool.Pool
}

func NewProductionOrderRepo(db *pgxpool.Pool) *ProductionOrderRepo {
	return &ProductionOrderRepo{db: db}
}

// generateOrderNumber creates "WO-YYYYMMDD-XXXXX" with a 5-digit sequence.
func (r *ProductionOrderRepo) generateOrderNumber(ctx context.Context, tenantID uuid.UUID) (string, error) {
	datePrefix := time.Now().UTC().Format("20060102")
	var seq int
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(MAX(CAST(SPLIT_PART(order_number, '-', 3) AS INTEGER)), 0) + 1
		FROM production_orders
		WHERE tenant_id = $1 AND order_number LIKE $2`,
		tenantID, "WO-"+datePrefix+"-%").Scan(&seq)
	if err != nil {
		// fallback: generate from sequence
		seq = int(time.Now().UnixNano() % 100000)
	}
	return fmt.Sprintf("WO-%s-%05d", datePrefix, seq), nil
}

func (r *ProductionOrderRepo) Create(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.CreateProductionOrderRequest) (*prodmodels.ProductionOrder, error) {
	orderNumber, err := r.generateOrderNumber(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("generate order number: %w", err)
	}

	priority := req.Priority
	if priority == "" {
		priority = "MEDIUM"
	}

	var plannedStart, plannedEnd *time.Time
	if req.PlannedStartDate != "" {
		t, err := parseTimeFlexible(req.PlannedStartDate)
		if err != nil {
			return nil, fmt.Errorf("invalid planned_start_date: %w", err)
		}
		plannedStart = &t
	}
	if req.PlannedEndDate != "" {
		t, err := parseTimeFlexible(req.PlannedEndDate)
		if err != nil {
			return nil, fmt.Errorf("invalid planned_end_date: %w", err)
		}
		plannedEnd = &t
	}

	po := &prodmodels.ProductionOrder{
		ID:               uuid.New(),
		TenantID:         tenantID,
		OrderNumber:      orderNumber,
		SiteID:           req.SiteID,
		MaterialID:       req.MaterialID,
		OrderQty:         req.OrderQty,
		BOMID:            req.BOMID,
		Status:           "DRAFT",
		Priority:         priority,
		SalesOrderID:     req.SalesOrderID,
		SOItemID:         req.SOItemID,
		PlannedStartDate: plannedStart,
		PlannedEndDate:   plannedEnd,
		Notes:            req.Notes,
		CreatedBy:        &userID,
		UpdatedBy:        &userID,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	_, err = r.db.Exec(ctx,
		`INSERT INTO production_orders (id, tenant_id, order_number, site_id, material_id, order_qty,
			bom_id, status, priority, sales_order_id, so_item_id,
			planned_start_date, planned_end_date,
			notes, created_by, updated_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,NOW(),NOW())`,
		po.ID, po.TenantID, po.OrderNumber, nullIfEmptyUUID(po.SiteID), po.MaterialID, po.OrderQty,
		nullIfEmptyUUID(po.BOMID), po.Status, po.Priority,
		nullIfEmptyUUID(po.SalesOrderID), nullIfEmptyUUID(po.SOItemID),
		po.PlannedStartDate, po.PlannedEndDate,
		nullIfEmpty(po.Notes), po.CreatedBy, po.UpdatedBy)
	if err != nil {
		return nil, fmt.Errorf("insert production order: %w", err)
	}

	// Enrich material name/sku
	r.enrichMaterialPO(ctx, po)
	return po, nil
}

func (r *ProductionOrderRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.ProductionOrder, error) {
	po := &prodmodels.ProductionOrder{}
	err := r.db.QueryRow(ctx,
		`SELECT po.id, po.tenant_id, po.order_number, po.site_id, COALESCE(s.site_code,''), COALESCE(s.site_name,''), po.material_id,
			COALESCE(p.name,''), COALESCE(p.sku,''),
			po.order_qty, po.completed_qty, po.bom_id, COALESCE(bh.bom_version,''),
			po.status, po.priority,
			po.sales_order_id, COALESCE(so.so_number,''),
			po.so_item_id,
			po.planned_start_date, po.planned_end_date,
			po.actual_start_date, po.actual_end_date,
			COALESCE(po.notes,''),
			po.created_by, po.updated_by, po.created_at, po.updated_at
		FROM production_orders po
		LEFT JOIN products p ON p.id = po.material_id
		LEFT JOIN sites s ON s.id = po.site_id
		LEFT JOIN bom_headers bh ON bh.bom_id = po.bom_id
		LEFT JOIN sales_orders so ON so.id = po.sales_order_id
		WHERE po.id = $1 AND po.tenant_id = $2`,
		id, tenantID).Scan(
		&po.ID, &po.TenantID, &po.OrderNumber, &po.SiteID, &po.SiteCode, &po.SiteName, &po.MaterialID,
		&po.MaterialName, &po.MaterialSKU,
		&po.OrderQty, &po.CompletedQty, &po.BOMID, &po.BOMVersion,
		&po.Status, &po.Priority,
		&po.SalesOrderID, &po.SalesOrderNumber,
		&po.SOItemID,
		&po.PlannedStartDate, &po.PlannedEndDate,
		&po.ActualStartDate, &po.ActualEndDate,
		&po.Notes,
		&po.CreatedBy, &po.UpdatedBy, &po.CreatedAt, &po.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get production order: %w", err)
	}
	// Load materials
	materials, err := r.loadPOMaterials(ctx, id, tenantID)
	if err == nil {
		po.Materials = materials
	}
	return po, nil
}

func (r *ProductionOrderRepo) List(ctx context.Context, tenantID uuid.UUID, materialID *uuid.UUID, status string) ([]*prodmodels.ProductionOrder, error) {
	query := `SELECT po.id, po.tenant_id, po.order_number, po.site_id, COALESCE(s.site_code,''), COALESCE(s.site_name,''), po.material_id,
			COALESCE(p.name,''), COALESCE(p.sku,''),
			po.order_qty, po.completed_qty, po.bom_id, COALESCE(bh.bom_version,''),
			po.status, po.priority,
			po.sales_order_id, COALESCE(so.so_number,''),
			po.so_item_id,
			po.planned_start_date, po.planned_end_date,
			po.actual_start_date, po.actual_end_date,
			COALESCE(po.notes,''),
			po.created_by, po.updated_by, po.created_at, po.updated_at
		FROM production_orders po
		LEFT JOIN products p ON p.id = po.material_id
		LEFT JOIN sites s ON s.id = po.site_id
		LEFT JOIN bom_headers bh ON bh.bom_id = po.bom_id
		LEFT JOIN sales_orders so ON so.id = po.sales_order_id
		WHERE po.tenant_id = $1`

	args := []interface{}{tenantID}
	argIdx := 2

	if materialID != nil {
		query += fmt.Sprintf(" AND po.material_id = $%d", argIdx)
		args = append(args, *materialID)
		argIdx++
	}
	if status != "" {
		query += fmt.Sprintf(" AND po.status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	query += " ORDER BY po.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list production orders: %w", err)
	}
	defer rows.Close()

	var list []*prodmodels.ProductionOrder
	for rows.Next() {
		po := &prodmodels.ProductionOrder{}
		if err := rows.Scan(
			&po.ID, &po.TenantID, &po.OrderNumber, &po.SiteID, &po.SiteCode, &po.SiteName, &po.MaterialID,
			&po.MaterialName, &po.MaterialSKU,
			&po.OrderQty, &po.CompletedQty, &po.BOMID, &po.BOMVersion,
			&po.Status, &po.Priority,
			&po.SalesOrderID, &po.SalesOrderNumber,
			&po.SOItemID,
			&po.PlannedStartDate, &po.PlannedEndDate,
			&po.ActualStartDate, &po.ActualEndDate,
			&po.Notes,
			&po.CreatedBy, &po.UpdatedBy, &po.CreatedAt, &po.UpdatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, po)
	}
	return list, nil
}

func (r *ProductionOrderRepo) Update(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateProductionOrderRequest, userID uuid.UUID) error {
	var plannedStart, plannedEnd, actualStart, actualEnd *string
	if req.PlannedStartDate != nil {
		if *req.PlannedStartDate != "" {
			_, err := parseTimeFlexible(*req.PlannedStartDate)
			if err != nil {
				return fmt.Errorf("invalid planned_start_date: %w", err)
			}
		}
		plannedStart = req.PlannedStartDate
	}
	if req.PlannedEndDate != nil {
		if *req.PlannedEndDate != "" {
			_, err := parseTimeFlexible(*req.PlannedEndDate)
			if err != nil {
				return fmt.Errorf("invalid planned_end_date: %w", err)
			}
		}
		plannedEnd = req.PlannedEndDate
	}
	if req.ActualStartDate != nil {
		if *req.ActualStartDate != "" {
			_, err := parseTimeFlexible(*req.ActualStartDate)
			if err != nil {
				return fmt.Errorf("invalid actual_start_date: %w", err)
			}
		}
		actualStart = req.ActualStartDate
	}
	if req.ActualEndDate != nil {
		if *req.ActualEndDate != "" {
			_, err := parseTimeFlexible(*req.ActualEndDate)
			if err != nil {
				return fmt.Errorf("invalid actual_end_date: %w", err)
			}
		}
		actualEnd = req.ActualEndDate
	}

	if req.Status != nil {
		validStatuses := map[string]bool{"DRAFT": true, "RELEASED": true, "IN_PROCESS": true, "PARTIALLY_PRODUCED": true, "COMPLETED": true, "CANCELLED": true}
		if !validStatuses[*req.Status] {
			return fmt.Errorf("400_INVALID_STATUS: %s", *req.Status)
		}
	}

	_, err := r.db.Exec(ctx,
		`UPDATE production_orders SET
			order_qty          = COALESCE($3, order_qty),
			site_id            = COALESCE($4, site_id),
			bom_id             = COALESCE($5, bom_id),
			status             = COALESCE($6, status),
			priority           = COALESCE($7, priority),
			sales_order_id     = COALESCE($8, sales_order_id),
			so_item_id         = COALESCE($9, so_item_id),
			planned_start_date = COALESCE($10::timestamptz, planned_start_date),
			planned_end_date   = COALESCE($11::timestamptz, planned_end_date),
			actual_start_date  = COALESCE($12::timestamptz, actual_start_date),
			actual_end_date    = COALESCE($13::timestamptz, actual_end_date),
			notes              = COALESCE($14, notes),
			updated_by         = $15,
			updated_at         = NOW()
		WHERE id = $1 AND tenant_id = $2`,
		id, tenantID, req.OrderQty, req.SiteID, req.BOMID, req.Status, req.Priority,
		req.SalesOrderID, req.SOItemID,
		plannedStart, plannedEnd, actualStart, actualEnd, req.Notes, &userID)
	return err
}

// Delete performs a soft delete: sets status='CANCELLED'.
func (r *ProductionOrderRepo) Delete(ctx context.Context, id, tenantID uuid.UUID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE production_orders SET
			status = 'CANCELLED',
			updated_by = $3,
			updated_at = NOW()
		WHERE id = $1 AND tenant_id = $2`,
		id, tenantID, &userID)
	return err
}

func (r *ProductionOrderRepo) enrichMaterialPO(ctx context.Context, po *prodmodels.ProductionOrder) {
	_ = r.db.QueryRow(ctx,
		`SELECT COALESCE(name,''), COALESCE(sku,'') FROM products WHERE id = $1`,
		po.MaterialID).Scan(&po.MaterialName, &po.MaterialSKU)
}

// loadPOMaterials loads production_order_materials rows for a given order.
func (r *ProductionOrderRepo) loadPOMaterials(ctx context.Context, orderID, tenantID uuid.UUID) ([]prodmodels.ProductionOrderMaterial, error) {
	rows, err := r.db.Query(ctx, `
		SELECT m.id, m.production_order_id, m.component_id,
			COALESCE(p.name,''), COALESCE(p.sku,''),
			m.bom_item_id, m.required_qty, m.issue_qty,
			m.unit_of_measure, m.item_position,
			m.created_at, m.updated_at
		FROM production_order_materials m
		LEFT JOIN products p ON p.id = m.component_id
		WHERE m.production_order_id = $1 AND m.tenant_id = $2
		ORDER BY m.item_position
	`, orderID, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []prodmodels.ProductionOrderMaterial
	for rows.Next() {
		var m prodmodels.ProductionOrderMaterial
		if err := rows.Scan(
			&m.ID, &m.ProductionOrderID, &m.ComponentID,
			&m.ComponentName, &m.ComponentSKU,
			&m.BOMItemID, &m.RequiredQty, &m.IssueQty,
			&m.UnitOfMeasure, &m.ItemPosition,
			&m.CreatedAt, &m.UpdatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, m)
	}
	return list, nil
}

// SyncPOMaterials explodes the BOM and upserts production_order_materials.
// Call this whenever bom_id or order_qty changes.
func (r *ProductionOrderRepo) SyncPOMaterials(ctx context.Context, orderID, tenantID uuid.UUID) error {
	// 1. Get order details
	var orderQty float64
	var bomID *uuid.UUID
	err := r.db.QueryRow(ctx,
		`SELECT order_qty, bom_id FROM production_orders WHERE id = $1 AND tenant_id = $2`,
		orderID, tenantID).Scan(&orderQty, &bomID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}
	if bomID == nil {
		// No BOM — clear materials
		_, err = r.db.Exec(ctx,
			`DELETE FROM production_order_materials WHERE production_order_id = $1`, orderID)
		return err
	}

	// 2. Load BOM items
	rows, err := r.db.Query(ctx, `
		SELECT bi.item_id, bi.component_id, bi.quantity, bi.unit_of_measure,
			bi.scrap_factor, bi.item_position,
			COALESCE(p.name,''), COALESCE(p.sku,'')
		FROM bom_items bi
		LEFT JOIN products p ON p.id = bi.component_id
		WHERE bi.bom_id = $1
		ORDER BY bi.item_position
	`, *bomID)
	if err != nil {
		return fmt.Errorf("load bom items: %w", err)
	}
	defer rows.Close()

	type bomLine struct {
		ItemID      uuid.UUID
		ComponentID uuid.UUID
		Qty         float64
		UOM         string
		Scrap       float64
		Pos         int
	}
	var lines []bomLine
	for rows.Next() {
		var l bomLine
		var name, sku string
		if err := rows.Scan(&l.ItemID, &l.ComponentID, &l.Qty, &l.UOM, &l.Scrap, &l.Pos, &name, &sku); err != nil {
			return err
		}
		lines = append(lines, l)
	}
	rows.Close()

	// 3. Upsert in transaction
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Delete lines not in BOM anymore
	if len(lines) > 0 {
		var bomItemIDs []uuid.UUID
		for _, l := range lines {
			bomItemIDs = append(bomItemIDs, l.ItemID)
		}
		_, err = tx.Exec(ctx, `
			DELETE FROM production_order_materials
			WHERE production_order_id = $1
			  AND bom_item_id IS NOT NULL
			  AND bom_item_id != ALL($2)
		`, orderID, bomItemIDs)
		if err != nil {
			return fmt.Errorf("delete stale materials: %w", err)
		}
	} else {
		_, err = tx.Exec(ctx,
			`DELETE FROM production_order_materials WHERE production_order_id = $1`, orderID)
		if err != nil {
			return err
		}
	}

	for _, l := range lines {
		// required_qty = order_qty * component_qty / (1 - scrap_factor)
		scrap := l.Scrap
		if scrap >= 1 {
			scrap = 0
		}
		requiredQty := orderQty * l.Qty / (1 - scrap)
		uom := l.UOM
		if uom == "" {
			uom = "EA"
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO production_order_materials
				(id, tenant_id, production_order_id, component_id, bom_item_id,
				 required_qty, unit_of_measure, item_position, issue_qty, created_at, updated_at)
			VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, 0, NOW(), NOW())
			ON CONFLICT (production_order_id, bom_item_id)
			DO UPDATE SET
				required_qty   = EXCLUDED.required_qty,
				unit_of_measure = EXCLUDED.unit_of_measure,
				item_position  = EXCLUDED.item_position,
				updated_at     = NOW()
		`, tenantID, orderID, l.ComponentID, l.ItemID, requiredQty, uom, l.Pos)
		if err != nil {
			return fmt.Errorf("upsert material line: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// UpdatePOMaterialIssueQty updates the issue_qty for a single material line.
func (r *ProductionOrderRepo) UpdatePOMaterialIssueQty(ctx context.Context, materialID, tenantID uuid.UUID, issueQty float64) error {
	_, err := r.db.Exec(ctx, `
		UPDATE production_order_materials
		SET issue_qty = $1, updated_at = NOW()
		WHERE id = $2 AND tenant_id = $3
	`, issueQty, materialID, tenantID)
	return err
}

func (r *ProductionOrderRepo) CreateTimeConfirmation(ctx context.Context, orderID, tenantID, userID uuid.UUID, req *prodmodels.CreateTimeConfirmationRequest) (*prodmodels.ProductionOrderTimeConfirmation, error) {
	confirmationDate := time.Now()
	if req.ConfirmationDate != "" {
		parsed, err := parseTimeFlexible(req.ConfirmationDate)
		if err != nil {
			return nil, fmt.Errorf("invalid confirmation_date: %w", err)
		}
		confirmationDate = parsed
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin time confirmation tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var orderNumber, materialSKU, materialName, status string
	var bomID *uuid.UUID
	var orderQty, completedQty float64
	err = tx.QueryRow(ctx, `
		SELECT po.order_number, COALESCE(p.sku,''), COALESCE(p.name,''),
			po.order_qty, po.completed_qty, po.status, po.bom_id
		FROM production_orders po
		LEFT JOIN products p ON p.id = po.material_id
		WHERE po.id = $1 AND po.tenant_id = $2
		FOR UPDATE OF po
	`, orderID, tenantID).Scan(&orderNumber, &materialSKU, &materialName, &orderQty, &completedQty, &status, &bomID)
	if err != nil {
		return nil, fmt.Errorf("load production order: %w", err)
	}
	if status != "RELEASED" && status != "IN_PROCESS" && status != "PARTIALLY_PRODUCED" {
		return nil, fmt.Errorf("production order %s is %s; only RELEASED, IN_PROCESS or PARTIALLY_PRODUCED orders can be confirmed", orderNumber, status)
	}

	var operationID *uuid.UUID
	var workCenterID *uuid.UUID
	var operationNo int
	var operationName, workCenterCode, workCenterName string
	isFinalOperation := true
	if req.OperationID != nil && *req.OperationID != uuid.Nil {
		if bomID == nil || *bomID == uuid.Nil {
			return nil, fmt.Errorf("production order %s has no BOM/routing; operation confirmation is not available", orderNumber)
		}
		var maxOperationNo int
		var opID, wcID uuid.UUID
		err = tx.QueryRow(ctx, `
			SELECT o.id, o.operation_no, o.operation_name, o.work_center_id,
				COALESCE(wc.code,''), COALESCE(wc.name,''),
				(SELECT COALESCE(MAX(o2.operation_no), 0)
				 FROM template_operations o2
				 JOIN bom_headers bh2 ON bh2.routing_template_id = o2.template_id
				 WHERE bh2.bom_id = $3 AND o2.tenant_id = $2 AND o2.is_active = true)
			FROM template_operations o
			JOIN bom_headers bh ON bh.routing_template_id = o.template_id
			LEFT JOIN work_centers wc ON wc.id = o.work_center_id
			WHERE o.id = $1 AND o.tenant_id = $2 AND bh.bom_id = $3 AND o.is_active = true
			LIMIT 1
		`, *req.OperationID, tenantID, *bomID).Scan(
			&opID, &operationNo, &operationName, &wcID,
			&workCenterCode, &workCenterName, &maxOperationNo,
		)
		if err != nil {
			return nil, fmt.Errorf("operation does not belong to production order %s routing: %w", orderNumber, err)
		}
		operationID = &opID
		workCenterID = &wcID
		isFinalOperation = operationNo >= maxOperationNo
	}

	remainingQty := orderQty - completedQty
	if isFinalOperation {
		if remainingQty <= 0 {
			return nil, fmt.Errorf("production order %s has no remaining quantity to confirm", orderNumber)
		}
		if req.YieldQty > remainingQty {
			return nil, fmt.Errorf("yield quantity %.4f exceeds remaining quantity %.4f for production order %s", req.YieldQty, remainingQty, orderNumber)
		}
	}

	confirmationID := uuid.New()
	now := time.Now()
	actualWorkHours := req.ActualWorkHours
	calculatedHours := req.SetupHours + req.LaborHours + req.MachineHours
	if actualWorkHours <= 0 {
		actualWorkHours = calculatedHours
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO production_order_time_confirmations
			(id, tenant_id, production_order_id, operation_id, work_center_id,
			 yield_qty, scrap_qty, rework_qty, setup_hours, labor_hours, machine_hours,
			 actual_work_hours, confirmation_date, notes, confirmed_by, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
	`, confirmationID, tenantID, orderID, operationID, workCenterID,
		req.YieldQty, req.ScrapQty, req.ReworkQty, req.SetupHours, req.LaborHours, req.MachineHours,
		actualWorkHours, confirmationDate, nullIfEmpty(req.Notes), userID, now)
	if err != nil {
		return nil, fmt.Errorf("insert time confirmation: %w", err)
	}

	newStatus := "IN_PROCESS"
	completedIncrement := 0.0
	if isFinalOperation {
		completedIncrement = req.YieldQty
		newStatus = "PARTIALLY_PRODUCED"
	}
	if completedQty+completedIncrement >= orderQty {
		newStatus = "COMPLETED"
	}
	_, err = tx.Exec(ctx, `
		UPDATE production_orders
		SET completed_qty = completed_qty + $1,
			status = $2::varchar,
			actual_start_date = COALESCE(actual_start_date, $3),
			actual_end_date = CASE WHEN $2::varchar = 'COMPLETED' THEN COALESCE(actual_end_date, $3) ELSE actual_end_date END,
			updated_by = $4,
			updated_at = NOW()
		WHERE id = $5 AND tenant_id = $6
	`, completedIncrement, newStatus, confirmationDate, userID, orderID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("update production order confirmation totals: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit time confirmation: %w", err)
	}

	return &prodmodels.ProductionOrderTimeConfirmation{
		ID:                confirmationID,
		TenantID:          tenantID,
		ProductionOrderID: orderID,
		OrderNumber:       orderNumber,
		MaterialSKU:       materialSKU,
		MaterialName:      materialName,
		OperationID:       operationID,
		OperationNo:       operationNo,
		OperationName:     operationName,
		WorkCenterID:      workCenterID,
		WorkCenterCode:    workCenterCode,
		WorkCenterName:    workCenterName,
		YieldQty:          req.YieldQty,
		ScrapQty:          req.ScrapQty,
		ReworkQty:         req.ReworkQty,
		SetupHours:        req.SetupHours,
		LaborHours:        req.LaborHours,
		MachineHours:      req.MachineHours,
		ActualWorkHours:   actualWorkHours,
		ConfirmationDate:  confirmationDate,
		Notes:             req.Notes,
		ConfirmedBy:       &userID,
		CreatedAt:         now,
	}, nil
}

func (r *ProductionOrderRepo) ListTimeConfirmations(ctx context.Context, orderID, tenantID uuid.UUID) ([]*prodmodels.ProductionOrderTimeConfirmation, error) {
	rows, err := r.db.Query(ctx, `
		SELECT c.id, c.tenant_id, c.production_order_id,
			COALESCE(po.order_number,''), COALESCE(p.sku,''), COALESCE(p.name,''),
			c.operation_id, COALESCE(o.operation_no, 0), COALESCE(o.operation_name, ''),
			c.work_center_id, COALESCE(wc.code,''), COALESCE(wc.name,''),
			c.yield_qty, c.scrap_qty, c.rework_qty, c.setup_hours, c.labor_hours, c.machine_hours,
			c.actual_work_hours, c.confirmation_date,
			COALESCE(c.notes,''), c.confirmed_by, c.created_at
		FROM production_order_time_confirmations c
		LEFT JOIN production_orders po ON po.id = c.production_order_id
		LEFT JOIN products p ON p.id = po.material_id
		LEFT JOIN template_operations o ON o.id = c.operation_id
		LEFT JOIN work_centers wc ON wc.id = c.work_center_id
		WHERE c.tenant_id = $1 AND c.production_order_id = $2
		ORDER BY c.confirmation_date DESC, c.created_at DESC
	`, tenantID, orderID)
	if err != nil {
		return nil, fmt.Errorf("list time confirmations: %w", err)
	}
	defer rows.Close()

	var list []*prodmodels.ProductionOrderTimeConfirmation
	for rows.Next() {
		c := &prodmodels.ProductionOrderTimeConfirmation{}
		if err := rows.Scan(&c.ID, &c.TenantID, &c.ProductionOrderID,
			&c.OrderNumber, &c.MaterialSKU, &c.MaterialName,
			&c.OperationID, &c.OperationNo, &c.OperationName,
			&c.WorkCenterID, &c.WorkCenterCode, &c.WorkCenterName,
			&c.YieldQty, &c.ScrapQty, &c.ReworkQty, &c.SetupHours, &c.LaborHours, &c.MachineHours,
			&c.ActualWorkHours, &c.ConfirmationDate,
			&c.Notes, &c.ConfirmedBy, &c.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, nil
}

func nullIfEmptyUUID(u *uuid.UUID) *uuid.UUID {
	if u == nil || *u == uuid.Nil {
		return nil
	}
	return u
}
