package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	models "github.com/swiftai-erp/backend/internal/authz/models"
)

type AccessRequestRepo struct {
	db *pgxpool.Pool
}

func NewAccessRequestRepo(db *pgxpool.Pool) *AccessRequestRepo {
	return &AccessRequestRepo{db: db}
}

func (r *AccessRequestRepo) Create(ctx context.Context, req *models.AccessRequest) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO access_requests (
			id, tenant_id, requester_id, target_user_id, request_type, request_data,
			justification, urgency, approval_status, executed, created_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'pending',false,NOW())`,
		req.ID, req.TenantID, req.RequesterID, req.TargetUserID, req.RequestType,
		[]byte(req.RequestData), req.Justification, req.Urgency)
	return err
}

func (r *AccessRequestRepo) List(ctx context.Context, tenantID uuid.UUID, status string) ([]*models.AccessRequest, error) {
	query := `
		SELECT id, tenant_id, requester_id, target_user_id, request_type, request_data,
		       COALESCE(justification,''), urgency, approver_id, approval_status,
		       approval_at, COALESCE(approval_comment,''), executed, executed_at, created_at
		FROM access_requests
		WHERE tenant_id=$1`
	args := []interface{}{tenantID}
	if status != "" && status != "all" {
		query += ` AND approval_status=$2`
		args = append(args, status)
	}
	query += ` ORDER BY created_at DESC`

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list access requests: %w", err)
	}
	defer rows.Close()

	var requests []*models.AccessRequest
	for rows.Next() {
		req := &models.AccessRequest{}
		if err := rows.Scan(
			&req.ID, &req.TenantID, &req.RequesterID, &req.TargetUserID,
			&req.RequestType, &req.RequestData, &req.Justification, &req.Urgency,
			&req.ApproverID, &req.ApprovalStatus, &req.ApprovalAt, &req.ApprovalComment,
			&req.Executed, &req.ExecutedAt, &req.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan access request: %w", err)
		}
		requests = append(requests, req)
	}
	return requests, nil
}

func (r *AccessRequestRepo) Get(ctx context.Context, id, tenantID uuid.UUID) (*models.AccessRequest, error) {
	req := &models.AccessRequest{}
	err := r.db.QueryRow(ctx, `
		SELECT id, tenant_id, requester_id, target_user_id, request_type, request_data,
		       COALESCE(justification,''), urgency, approver_id, approval_status,
		       approval_at, COALESCE(approval_comment,''), executed, executed_at, created_at
		FROM access_requests
		WHERE id=$1 AND tenant_id=$2`, id, tenantID).Scan(
		&req.ID, &req.TenantID, &req.RequesterID, &req.TargetUserID,
		&req.RequestType, &req.RequestData, &req.Justification, &req.Urgency,
		&req.ApproverID, &req.ApprovalStatus, &req.ApprovalAt, &req.ApprovalComment,
		&req.Executed, &req.ExecutedAt, &req.CreatedAt)
	if err != nil {
		return nil, err
	}
	return req, nil
}

func (r *AccessRequestRepo) Approve(ctx context.Context, id, tenantID, approverID uuid.UUID, status, comment string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE access_requests
		SET approval_status=$1, approver_id=$2, approval_at=NOW(), approval_comment=$3
		WHERE id=$4 AND tenant_id=$5 AND approval_status='pending'`,
		status, approverID, comment, id, tenantID)
	return err
}

func (r *AccessRequestRepo) MarkExecuted(ctx context.Context, id, tenantID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE access_requests SET executed=true, executed_at=NOW()
		WHERE id=$1 AND tenant_id=$2`, id, tenantID)
	return err
}
