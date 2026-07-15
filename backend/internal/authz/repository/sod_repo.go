package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type SoDRepo struct {
	db *pgxpool.Pool
}

func NewSoDRepo(db *pgxpool.Pool) *SoDRepo {
	return &SoDRepo{db: db}
}

func (r *SoDRepo) CreateRule(ctx context.Context, rule *models.SoDRule) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO sod_rules (
			id, tenant_id, rule_code, description, severity, risk_category,
			object_a_id, activity_a, object_b_id, activity_b, is_active, created_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
		rule.ID, rule.TenantID, rule.RuleCode, rule.Description, rule.Severity,
		rule.RiskCategory, rule.ObjectAID, rule.ActivityA, rule.ObjectBID,
		rule.ActivityB, rule.IsActive, time.Now())
	return err
}

func (r *SoDRepo) ListRules(ctx context.Context, tenantID uuid.UUID) ([]*models.SoDRule, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, tenant_id, rule_code, COALESCE(description,''), severity,
		       COALESCE(risk_category,''), object_a_id, COALESCE(activity_a,''),
		       object_b_id, COALESCE(activity_b,''), is_active
		FROM sod_rules
		WHERE tenant_id=$1
		ORDER BY severity DESC, rule_code`, tenantID)
	if err != nil {
		return nil, fmt.Errorf("list sod rules: %w", err)
	}
	defer rows.Close()

	var rules []*models.SoDRule
	for rows.Next() {
		rule := &models.SoDRule{}
		if err := rows.Scan(
			&rule.ID, &rule.TenantID, &rule.RuleCode, &rule.Description,
			&rule.Severity, &rule.RiskCategory, &rule.ObjectAID, &rule.ActivityA,
			&rule.ObjectBID, &rule.ActivityB, &rule.IsActive); err != nil {
			return nil, fmt.Errorf("scan sod rule: %w", err)
		}
		rules = append(rules, rule)
	}
	return rules, nil
}

func (r *SoDRepo) DeleteRule(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM sod_rules WHERE id=$1 AND tenant_id=$2`, id, tenantID)
	return err
}

func (r *SoDRepo) CheckRoleAssignmentConflicts(ctx context.Context, tenantID, userID, newRoleID uuid.UUID) ([]*models.SoDConflict, error) {
	rows, err := r.db.Query(ctx, `
		WITH existing_direct AS (
			SELECT rm.* FROM role_master rm
			INNER JOIN user_role_assignments ura ON ura.role_id = rm.id
			WHERE ura.user_id = $2 AND ura.is_active = true
			  AND (ura.valid_to IS NULL OR ura.valid_to > NOW())
		),
		existing_roles AS (
			SELECT * FROM existing_direct
			UNION
			SELECT rm.* FROM role_master rm
			INNER JOIN composite_role_members crm ON crm.child_role_id = rm.id
			INNER JOIN existing_direct er ON er.id = crm.composite_role_id
			WHERE rm.is_active = true
			UNION
			SELECT parent.* FROM role_master parent
			INNER JOIN existing_direct child ON child.parent_role_id = parent.id
			WHERE child.role_type = 'derived' AND parent.is_active = true
		),
		new_direct AS (
			SELECT * FROM role_master WHERE id = $3
		),
		new_roles AS (
			SELECT * FROM new_direct
			UNION
			SELECT rm.* FROM role_master rm
			INNER JOIN composite_role_members crm ON crm.child_role_id = rm.id
			INNER JOIN new_direct nr ON nr.id = crm.composite_role_id
			WHERE rm.is_active = true
			UNION
			SELECT parent.* FROM role_master parent
			INNER JOIN new_direct child ON child.parent_role_id = parent.id
			WHERE child.role_type = 'derived' AND parent.is_active = true
		),
		existing_auth AS (
			SELECT er.id AS role_id, er.role_id AS role_code, rav.auth_object_id, rav.activity_create, rav.activity_read,
			       rav.activity_update, rav.activity_delete, rav.activity_approve, rav.activity_print, rav.activity_transfer, rav.activity_close
			FROM existing_roles er
			INNER JOIN role_auth_values rav ON rav.role_id = er.id
		),
		new_auth AS (
			SELECT nr.id AS role_id, nr.role_id AS role_code, rav.auth_object_id, rav.activity_create, rav.activity_read,
			       rav.activity_update, rav.activity_delete, rav.activity_approve, rav.activity_print, rav.activity_transfer, rav.activity_close
			FROM new_roles nr
			INNER JOIN role_auth_values rav ON rav.role_id = nr.id
		)
		SELECT sr.id, sr.rule_code, COALESCE(sr.description,''), sr.severity, COALESCE(sr.risk_category,''),
		       ea.role_id, ea.role_code, na.role_id, na.role_code,
		       aoa.object_code, COALESCE(sr.activity_a,''), aob.object_code, COALESCE(sr.activity_b,'')
		FROM sod_rules sr
		INNER JOIN auth_objects aoa ON aoa.id = sr.object_a_id
		INNER JOIN auth_objects aob ON aob.id = sr.object_b_id
		INNER JOIN existing_auth ea ON ea.auth_object_id = sr.object_a_id
		INNER JOIN new_auth na ON na.auth_object_id = sr.object_b_id
		WHERE sr.tenant_id=$1 AND sr.is_active=true
		  AND (COALESCE(sr.activity_a,'')='' OR (sr.activity_a='create' AND ea.activity_create) OR (sr.activity_a='read' AND ea.activity_read) OR (sr.activity_a='update' AND ea.activity_update) OR (sr.activity_a='delete' AND ea.activity_delete) OR (sr.activity_a='approve' AND ea.activity_approve) OR (sr.activity_a='print' AND ea.activity_print) OR (sr.activity_a='transfer' AND ea.activity_transfer) OR (sr.activity_a='close' AND ea.activity_close))
		  AND (COALESCE(sr.activity_b,'')='' OR (sr.activity_b='create' AND na.activity_create) OR (sr.activity_b='read' AND na.activity_read) OR (sr.activity_b='update' AND na.activity_update) OR (sr.activity_b='delete' AND na.activity_delete) OR (sr.activity_b='approve' AND na.activity_approve) OR (sr.activity_b='print' AND na.activity_print) OR (sr.activity_b='transfer' AND na.activity_transfer) OR (sr.activity_b='close' AND na.activity_close))
		UNION
		SELECT sr.id, sr.rule_code, COALESCE(sr.description,''), sr.severity, COALESCE(sr.risk_category,''),
		       ea.role_id, ea.role_code, na.role_id, na.role_code,
		       aob.object_code, COALESCE(sr.activity_b,''), aoa.object_code, COALESCE(sr.activity_a,'')
		FROM sod_rules sr
		INNER JOIN auth_objects aoa ON aoa.id = sr.object_a_id
		INNER JOIN auth_objects aob ON aob.id = sr.object_b_id
		INNER JOIN existing_auth ea ON ea.auth_object_id = sr.object_b_id
		INNER JOIN new_auth na ON na.auth_object_id = sr.object_a_id
		WHERE sr.tenant_id=$1 AND sr.is_active=true
		  AND (COALESCE(sr.activity_b,'')='' OR (sr.activity_b='create' AND ea.activity_create) OR (sr.activity_b='read' AND ea.activity_read) OR (sr.activity_b='update' AND ea.activity_update) OR (sr.activity_b='delete' AND ea.activity_delete) OR (sr.activity_b='approve' AND ea.activity_approve) OR (sr.activity_b='print' AND ea.activity_print) OR (sr.activity_b='transfer' AND ea.activity_transfer) OR (sr.activity_b='close' AND ea.activity_close))
		  AND (COALESCE(sr.activity_a,'')='' OR (sr.activity_a='create' AND na.activity_create) OR (sr.activity_a='read' AND na.activity_read) OR (sr.activity_a='update' AND na.activity_update) OR (sr.activity_a='delete' AND na.activity_delete) OR (sr.activity_a='approve' AND na.activity_approve) OR (sr.activity_a='print' AND na.activity_print) OR (sr.activity_a='transfer' AND na.activity_transfer) OR (sr.activity_a='close' AND na.activity_close))`,
		tenantID, userID, newRoleID)
	if err != nil {
		return nil, fmt.Errorf("check sod conflicts: %w", err)
	}
	defer rows.Close()

	var conflicts []*models.SoDConflict
	for rows.Next() {
		conflict := &models.SoDConflict{}
		if err := rows.Scan(
			&conflict.RuleID, &conflict.RuleCode, &conflict.Description,
			&conflict.Severity, &conflict.RiskCategory,
			&conflict.RoleAID, &conflict.RoleA, &conflict.RoleBID, &conflict.RoleB,
			&conflict.ObjectA, &conflict.ActivityA, &conflict.ObjectB, &conflict.ActivityB); err != nil {
			return nil, fmt.Errorf("scan sod conflict: %w", err)
		}
		conflicts = append(conflicts, conflict)
	}
	return conflicts, nil
}
