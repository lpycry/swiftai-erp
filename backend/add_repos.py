import os

repo_file = r'C:\SwiftAIERP\backend\internal\production\repository\production_repo.go'
models = r'C:\SwiftAIERP\backend\internal\production\models\models.go'

# Read current repo
with open(repo_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import for fmt if not present
if 'import (' in content:
    # Find the import block
    idx = content.find('import (')
    end = content.find(')', idx)
    imports = content[idx:end]
    if '"fmt"' not in imports:
        content = content[:end] + '\t"fmt"\n' + content[end:]

# Add new repos at the end (before the nullIfEmpty helper)
helper_idx = content.find('func nullIfEmpty')
if helper_idx < 0:
    helper_idx = len(content)

new_code = '''
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
		ID:               uuid.New(),
		TenantID:         tenantID,
		Code:             req.Code,
		Name:             req.Name,
		Description:      req.Description,
		WorkCenterType:   req.WorkCenterType,
		AvailableCapacity: req.AvailableCapacity,
		EfficiencyRate:   req.EfficiencyRate,
		CostPerHour:      req.CostPerHour,
		PlantLocation:    req.PlantLocation,
		IsActive:         true,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
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
	_, err := r.db.Exec(ctx, `
		UPDATE routing_templates SET
			template_code = COALESCE($3, template_code),
			template_name = COALESCE($4, template_name),
			description   = COALESCE($5, description),
			version       = COALESCE($6, version),
			status        = COALESCE($7, status),
			is_active     = COALESCE($8, is_active),
			updated_at    = NOW()
		WHERE id = $1 AND tenant_id = $2
	`, id, tenantID, req.TemplateCode, req.TemplateName, req.Description, req.Version, req.Status, req.IsActive)
	return err
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

'''

# Insert the new code before nullIfEmpty or at end
if helper_idx >= 0 and helper_idx < len(content):
    content = content[:helper_idx] + new_code + content[helper_idx:]
else:
    content += new_code

with open(repo_file, 'w', encoding='utf-8') as f:
    f.write(content)
print('Repo updated')
