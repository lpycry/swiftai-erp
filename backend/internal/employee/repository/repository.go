package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	emodels "github.com/swiftai-erp/backend/internal/employee/models"
)

type EmployeeRepo struct {
	db *pgxpool.Pool
}

func NewEmployeeRepo(db *pgxpool.Pool) *EmployeeRepo {
	return &EmployeeRepo{db: db}
}

const empSelectCols = `id, tenant_id, employee_code,
	COALESCE(first_name,'') as first_name, COALESCE(middle_name,'') as middle_name, COALESCE(last_name,'') as last_name,
	COALESCE(first_name,'') || CASE WHEN COALESCE(middle_name,'') != '' THEN ' ' || middle_name ELSE '' END || ' ' || COALESCE(last_name,'') as legal_name,
	COALESCE(tax_id,'') as tax_id, COALESCE(date_of_birth::text,'') as date_of_birth,
	position_id, department_id,
	COALESCE(hire_date::text,'') as hire_date,
	COALESCE(email,'') as email, COALESCE(phone,'') as phone,
	COALESCE(legal_address,'') as legal_address,
	COALESCE(emergency_contacts::text,'[]') as emergency_contacts,
	COALESCE(worker_type,'Regular') as worker_type,
	manager_id,
	is_active, created_at, updated_at`

func (r *EmployeeRepo) CreateBase(ctx context.Context, emp *emodels.EmployeeBase) error {
	var posID, deptID, mgrID interface{} = nil, nil, nil
	if emp.PositionID != nil { posID = *emp.PositionID }
	if emp.DepartmentID != nil { deptID = *emp.DepartmentID }
	if emp.ManagerID != nil { mgrID = *emp.ManagerID }

	query := `
		INSERT INTO employee_base (id, tenant_id, employee_code,
			first_name, middle_name, last_name,
			tax_id, date_of_birth,
			position_id, department_id, hire_date,
			email, phone, legal_address, emergency_contacts,
			worker_type, manager_id,
			is_active, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,NULLIF($8,'')::date,
			$9,$10,NULLIF($11,'')::date,$12,$13,$14,$15::jsonb,
			$16,$17,$18,$19,$20)
	`
	_, err := r.db.Exec(ctx, query,
		emp.ID, emp.TenantID, emp.EmployeeCode,
		emp.FirstName, emp.MiddleName, emp.LastName,
		emp.TaxID, emp.DateOfBirth,
		posID, deptID, emp.HireDate,
		emp.Email, emp.Phone, emp.LegalAddress, emp.EmergencyContacts,
		emp.WorkerType, mgrID,
		emp.IsActive, emp.CreatedAt, emp.UpdatedAt,
	)
	if err != nil { return fmt.Errorf("create employee: %w", err) }
	return nil
}

func scanEmp(row pgx.Row) (*emodels.EmployeeBase, error) {
	emp := &emodels.EmployeeBase{}
	err := row.Scan(
		&emp.ID, &emp.TenantID, &emp.EmployeeCode,
		&emp.FirstName, &emp.MiddleName, &emp.LastName, &emp.LegalName,
		&emp.TaxID, &emp.DateOfBirth,
		&emp.PositionID, &emp.DepartmentID, &emp.HireDate,
		&emp.Email, &emp.Phone, &emp.LegalAddress, &emp.EmergencyContacts,
		&emp.WorkerType, &emp.ManagerID,
		&emp.IsActive, &emp.CreatedAt, &emp.UpdatedAt,
	)
	return emp, err
}

func scanEmps(rows pgx.Rows) ([]*emodels.EmployeeBase, error) {
	var list []*emodels.EmployeeBase
	for rows.Next() {
		emp, err := scanEmp(rows)
		if err != nil { return nil, fmt.Errorf("scan employee: %w", err) }
		list = append(list, emp)
	}
	return list, nil
}

func (r *EmployeeRepo) GetBaseByID(ctx context.Context, id, tenantID uuid.UUID) (*emodels.EmployeeBase, error) {
	emp, err := scanEmp(r.db.QueryRow(ctx, `SELECT `+empSelectCols+` FROM employee_base WHERE id = $1 AND tenant_id = $2`, id, tenantID))
	if err != nil {
		if err == pgx.ErrNoRows { return nil, nil }
		return nil, fmt.Errorf("get employee: %w", err)
	}
	return emp, nil
}

func (r *EmployeeRepo) ListBase(ctx context.Context, tenantID uuid.UUID, search string) ([]*emodels.EmployeeBase, error) {
	var rows pgx.Rows
	var err error
	q := `SELECT ` + empSelectCols + ` FROM employee_base WHERE tenant_id = $1`
	if search == "" {
		rows, err = r.db.Query(ctx, q+` ORDER BY employee_code`, tenantID)
	} else {
		like := "%" + search + "%"
		rows, err = r.db.Query(ctx, q+` AND (employee_code ILIKE $2 OR first_name ILIKE $2 OR last_name ILIKE $2 OR email ILIKE $2) ORDER BY employee_code`, tenantID, like)
	}
	if err != nil { return nil, fmt.Errorf("list employees: %w", err) }
	defer rows.Close()
	return scanEmps(rows)
}

func (r *EmployeeRepo) UpdateBase(ctx context.Context, id, tenantID uuid.UUID, req *emodels.UpdateEmployeeRequest) (*emodels.EmployeeBase, error) {
	setClauses := make([]string, 0, 15)
	args := []interface{}{}
	argIdx := 1

	addCol := func(col string, expr string, val interface{}) {
		setClauses = append(setClauses, fmt.Sprintf("%s = %s", col, expr))
		args = append(args, val); argIdx++
	}
	if req.FirstName != "" { addCol("first_name", fmt.Sprintf("$%d", argIdx), req.FirstName) }
	if req.MiddleName != "" { addCol("middle_name", fmt.Sprintf("$%d", argIdx), req.MiddleName) }
	if req.LastName != "" { addCol("last_name", fmt.Sprintf("$%d", argIdx), req.LastName) }
	if req.TaxID != "" { addCol("tax_id", fmt.Sprintf("$%d", argIdx), req.TaxID) }
	if req.DateOfBirth != "" { addCol("date_of_birth", fmt.Sprintf("NULLIF($%d,'')::date", argIdx), req.DateOfBirth) }
	if req.PositionID != "" { addCol("position_id", fmt.Sprintf("$%d::uuid", argIdx), req.PositionID) }
	if req.DepartmentID != "" { addCol("department_id", fmt.Sprintf("$%d::uuid", argIdx), req.DepartmentID) }
	if req.HireDate != "" { addCol("hire_date", fmt.Sprintf("NULLIF($%d,'')::date", argIdx), req.HireDate) }
	if req.Email != "" { addCol("email", fmt.Sprintf("$%d", argIdx), req.Email) }
	if req.Phone != "" { addCol("phone", fmt.Sprintf("$%d", argIdx), req.Phone) }
	if req.LegalAddress != "" { addCol("legal_address", fmt.Sprintf("$%d", argIdx), req.LegalAddress) }
	if req.EmergencyContacts != "" { addCol("emergency_contacts", fmt.Sprintf("$%d::jsonb", argIdx), req.EmergencyContacts) }
	if req.WorkerType != "" { addCol("worker_type", fmt.Sprintf("$%d", argIdx), req.WorkerType) }
	if req.ManagerID != "" { addCol("manager_id", fmt.Sprintf("$%d::uuid", argIdx), req.ManagerID) }
	if req.IsActive != nil { addCol("is_active", fmt.Sprintf("$%d", argIdx), *req.IsActive) }

	if len(setClauses) == 0 { return r.GetBaseByID(ctx, id, tenantID) }

	addCol("updated_at", fmt.Sprintf("$%d", argIdx), time.Now())
	args = append(args, id, tenantID)

	query := fmt.Sprintf(`UPDATE employee_base SET %s WHERE id = $%d AND tenant_id = $%d RETURNING `+empSelectCols,
		strings.Join(setClauses, ", "), argIdx, argIdx+1)

	emp, err := scanEmp(r.db.QueryRow(ctx, query, args...))
	if err != nil {
		if err == pgx.ErrNoRows { return nil, nil }
		return nil, fmt.Errorf("update employee: %w", err)
	}
	return emp, nil
}

func (r *EmployeeRepo) DeleteBase(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM employee_data_history WHERE employee_id = $1", id)
	if err != nil { return fmt.Errorf("delete history: %w", err) }
	// Clear manager references
	r.db.Exec(ctx, "UPDATE employee_base SET manager_id = NULL WHERE manager_id = $1", id)
	_, err = r.db.Exec(ctx, "DELETE FROM employee_base WHERE id = $1 AND tenant_id = $2", id, tenantID)
	return err
}

// ── Data History (Infotype) ──

func (r *EmployeeRepo) CreateHistory(ctx context.Context, rec *emodels.EmployeeDataHistory) error {
	_, _ = r.db.Exec(ctx, `
		UPDATE employee_data_history SET valid_to = ($1::date - INTERVAL '1 day')::date, updated_at = NOW()
		WHERE employee_id = $2 AND infotype_code = $3 AND valid_to = '9999-12-31' AND valid_from < $1::date
	`, rec.ValidFrom, rec.EmployeeID, rec.InfotypeCode)
	_, err := r.db.Exec(ctx, `
		INSERT INTO employee_data_history (record_id, employee_id, infotype_code, data_payload, valid_from, valid_to, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5::date, NULLIF($6,'')::date, $7, $8)
	`, rec.RecordID, rec.EmployeeID, rec.InfotypeCode, rec.DataPayload, rec.ValidFrom, rec.ValidTo, rec.CreatedAt, rec.UpdatedAt)
	return err
}

func (r *EmployeeRepo) ListHistory(ctx context.Context, employeeID uuid.UUID, infotypeCode string) ([]*emodels.EmployeeDataHistory, error) {
	query := `SELECT record_id, employee_id, infotype_code, data_payload, valid_from::text, valid_to::text, created_at, updated_at FROM employee_data_history WHERE employee_id = $1`
	args := []interface{}{employeeID}
	if infotypeCode != "" { query += ` AND infotype_code = $2`; args = append(args, infotypeCode) }
	query += ` ORDER BY infotype_code, valid_from DESC`
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil { return nil, fmt.Errorf("list history: %w", err) }
	defer rows.Close()
	var list []*emodels.EmployeeDataHistory
	for rows.Next() {
		rec := &emodels.EmployeeDataHistory{}
		err := rows.Scan(&rec.RecordID, &rec.EmployeeID, &rec.InfotypeCode, &rec.DataPayload, &rec.ValidFrom, &rec.ValidTo, &rec.CreatedAt, &rec.UpdatedAt)
		if err != nil { return nil, fmt.Errorf("scan history: %w", err) }
		list = append(list, rec)
	}
	return list, nil
}

func (r *EmployeeRepo) UpdateHistory(ctx context.Context, recordID uuid.UUID, req *emodels.UpdateDataHistoryRequest) (*emodels.EmployeeDataHistory, error) {
	setClauses := make([]string, 0, 3)
	args := []interface{}{}
	argIdx := 1
	if req.DataPayload != nil { setClauses = append(setClauses, fmt.Sprintf("data_payload = $%d", argIdx)); args = append(args, req.DataPayload); argIdx++ }
	if req.ValidFrom != "" { setClauses = append(setClauses, fmt.Sprintf("valid_from = $%d::date", argIdx)); args = append(args, req.ValidFrom); argIdx++ }
	if req.ValidTo != "" { setClauses = append(setClauses, fmt.Sprintf("valid_to = NULLIF($%d,'')::date", argIdx)); args = append(args, req.ValidTo); argIdx++ }
	if len(setClauses) == 0 { return r.GetHistoryByID(ctx, recordID) }
	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now()); argIdx++
	args = append(args, recordID)
	query := fmt.Sprintf(`UPDATE employee_data_history SET %s WHERE record_id = $%d RETURNING record_id, employee_id, infotype_code, data_payload, valid_from::text, valid_to::text, created_at, updated_at`, strings.Join(setClauses, ", "), argIdx)
	rec := &emodels.EmployeeDataHistory{}
	err := r.db.QueryRow(ctx, query, args...).Scan(&rec.RecordID, &rec.EmployeeID, &rec.InfotypeCode, &rec.DataPayload, &rec.ValidFrom, &rec.ValidTo, &rec.CreatedAt, &rec.UpdatedAt)
	if err != nil { if err == pgx.ErrNoRows { return nil, nil }; return nil, fmt.Errorf("update history: %w", err) }
	return rec, nil
}

func (r *EmployeeRepo) DeleteHistory(ctx context.Context, recordID uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM employee_data_history WHERE record_id = $1", recordID)
	return err
}

func (r *EmployeeRepo) GetHistoryByID(ctx context.Context, recordID uuid.UUID) (*emodels.EmployeeDataHistory, error) {
	rec := &emodels.EmployeeDataHistory{}
	err := r.db.QueryRow(ctx, `SELECT record_id, employee_id, infotype_code, data_payload, valid_from::text, valid_to::text, created_at, updated_at FROM employee_data_history WHERE record_id = $1`, recordID).Scan(
		&rec.RecordID, &rec.EmployeeID, &rec.InfotypeCode, &rec.DataPayload, &rec.ValidFrom, &rec.ValidTo, &rec.CreatedAt, &rec.UpdatedAt)
	if err != nil { if err == pgx.ErrNoRows { return nil, nil }; return nil, fmt.Errorf("get history: %w", err) }
	return rec, nil
}

// ── Current View ──

func (r *EmployeeRepo) ListCurrentView(ctx context.Context, tenantID uuid.UUID, search string) ([]map[string]interface{}, error) {
	q := `SELECT eb.id, eb.employee_code, eb.first_name, eb.last_name,
		COALESCE(eb.first_name,'') || ' ' || COALESCE(eb.last_name,'') as full_name,
		eb.tax_id, eb.date_of_birth::text, eb.is_active,
		eb.position_id::text, eb.department_id::text, eb.hire_date::text,
		eb.email, eb.phone, eb.legal_address, eb.worker_type, eb.manager_id::text,
		COALESCE(po.position_code,''), COALESCE(po.position_title,''),
		COALESCE(ou.unit_code,'') as dept_code, COALESCE(ou.unit_name,'') as dept_name,
		COALESCE(ou.cost_center_id, po_cc.cost_center_id, '') as cost_center_id
		FROM employee_base eb
		LEFT JOIN positions po ON po.id = eb.position_id
		LEFT JOIN organization_units ou ON ou.id = eb.department_id
		LEFT JOIN organization_units po_cc ON po_cc.id = po.org_unit_id
		WHERE eb.tenant_id = $1`
	args := []interface{}{tenantID}
	if search != "" {
		q += ` AND (eb.employee_code ILIKE $2 OR eb.first_name ILIKE $2 OR eb.last_name ILIKE $2 OR eb.email ILIKE $2)`
		args = append(args, "%"+search+"%")
	}
	q += ` ORDER BY eb.employee_code`
	rows, err := r.db.Query(ctx, q, args...)
	if err != nil { return nil, fmt.Errorf("list current view: %w", err) }
	defer rows.Close()
	var result []map[string]interface{}
	for rows.Next() {
		values, err := rows.Values()
		if err != nil { return nil, fmt.Errorf("read row: %w", err) }
		fields := []string{"employee_id","employee_code","first_name","last_name","full_name","tax_id","date_of_birth","is_active",
			"position_id","department_id","hire_date","email","phone","legal_address","worker_type","manager_id",
			"position_code","position_title","dept_code","dept_name","cost_center_id"}
		row := make(map[string]interface{})
		for i, name := range fields {
			if i < len(values) {
				v := values[i]
				// Convert uuid.UUID [16]byte to string for JSON serialization
				if b, ok := v.([16]byte); ok {
					v = fmt.Sprintf("%08x-%04x-%04x-%04x-%012x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
				}
				row[name] = v
			}
		}
		result = append(result, row)
	}
	return result, nil
}
