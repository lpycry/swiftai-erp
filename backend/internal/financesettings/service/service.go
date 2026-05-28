package service

import (
	"context"

	"github.com/google/uuid"

	fsmodels "github.com/swiftai-erp/backend/internal/financesettings/models"
	fsrepo "github.com/swiftai-erp/backend/internal/financesettings/repository"
)

type FinanceSettingsService struct {
	repo *fsrepo.FinanceSettingsRepo
}

func NewFinanceSettingsService(repo *fsrepo.FinanceSettingsRepo) *FinanceSettingsService {
	return &FinanceSettingsService{repo: repo}
}

// ── Payment Terms ──

func (s *FinanceSettingsService) ListPaymentTerms(ctx context.Context, tenantID uuid.UUID) ([]*fsmodels.PaymentTerm, error) {
	return s.repo.ListPaymentTerms(ctx, tenantID)
}

func (s *FinanceSettingsService) CreatePaymentTerm(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreatePaymentTermRequest) (*fsmodels.PaymentTerm, error) {
	return s.repo.CreatePaymentTerm(ctx, tenantID, req)
}

func (s *FinanceSettingsService) UpdatePaymentTerm(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdatePaymentTermRequest) error {
	return s.repo.UpdatePaymentTerm(ctx, id, tenantID, req)
}

func (s *FinanceSettingsService) DeletePaymentTerm(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeletePaymentTerm(ctx, id, tenantID)
}

// ── Incoterms ──

func (s *FinanceSettingsService) ListIncoterms(ctx context.Context, tenantID uuid.UUID) ([]*fsmodels.Incoterm, error) {
	return s.repo.ListIncoterms(ctx, tenantID)
}

func (s *FinanceSettingsService) CreateIncoterm(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateIncotermRequest) (*fsmodels.Incoterm, error) {
	return s.repo.CreateIncoterm(ctx, tenantID, req)
}

func (s *FinanceSettingsService) UpdateIncoterm(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateIncotermRequest) error {
	return s.repo.UpdateIncoterm(ctx, id, tenantID, req)
}

func (s *FinanceSettingsService) DeleteIncoterm(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteIncoterm(ctx, id, tenantID)
}

// ── Org Reconciliation Accounts ──

func (s *FinanceSettingsService) ListOrgReconAccounts(ctx context.Context, orgID uuid.UUID) ([]*fsmodels.OrgReconAccount, error) {
	return s.repo.ListOrgReconAccounts(ctx, orgID)
}

func (s *FinanceSettingsService) CreateOrgReconAccount(ctx context.Context, req *fsmodels.CreateOrgReconAccountRequest) (*fsmodels.OrgReconAccount, error) {
	return s.repo.CreateOrgReconAccount(ctx, req)
}

func (s *FinanceSettingsService) UpdateOrgReconAccount(ctx context.Context, id uuid.UUID, req *fsmodels.CreateOrgReconAccountRequest) (*fsmodels.OrgReconAccount, error) {
	return s.repo.UpdateOrgReconAccount(ctx, id, req)
}

func (s *FinanceSettingsService) DeleteOrgReconAccount(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteOrgReconAccount(ctx, id)
}
