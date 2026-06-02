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

// ── Tax Jurisdictions ──

func (s *FinanceSettingsService) ListTaxJurisdictions(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*fsmodels.TaxJurisdiction, error) {
	return s.repo.ListTaxJurisdictions(ctx, tenantID, activeOnly)
}

func (s *FinanceSettingsService) GetTaxJurisdiction(ctx context.Context, id uuid.UUID) (*fsmodels.TaxJurisdiction, error) {
	return s.repo.GetTaxJurisdiction(ctx, id)
}

func (s *FinanceSettingsService) CreateTaxJurisdiction(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateTaxJurisdictionRequest) (*fsmodels.TaxJurisdiction, error) {
	return s.repo.CreateTaxJurisdiction(ctx, tenantID, req)
}

func (s *FinanceSettingsService) UpdateTaxJurisdiction(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateTaxJurisdictionRequest) error {
	return s.repo.UpdateTaxJurisdiction(ctx, id, tenantID, req)
}

func (s *FinanceSettingsService) DeleteTaxJurisdiction(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteTaxJurisdiction(ctx, id, tenantID)
}

// ── Tax Nexus ──

func (s *FinanceSettingsService) ListTaxNexus(ctx context.Context, tenantID uuid.UUID, activeOnly bool) ([]*fsmodels.TaxNexus, error) {
	return s.repo.ListTaxNexus(ctx, tenantID, activeOnly)
}

func (s *FinanceSettingsService) GetTaxNexus(ctx context.Context, id uuid.UUID) (*fsmodels.TaxNexus, error) {
	return s.repo.GetTaxNexus(ctx, id)
}

func (s *FinanceSettingsService) CreateTaxNexus(ctx context.Context, tenantID uuid.UUID, req *fsmodels.CreateTaxNexusRequest) (*fsmodels.TaxNexus, error) {
	return s.repo.CreateTaxNexus(ctx, tenantID, req)
}

func (s *FinanceSettingsService) UpdateTaxNexus(ctx context.Context, id, tenantID uuid.UUID, req *fsmodels.UpdateTaxNexusRequest) error {
	return s.repo.UpdateTaxNexus(ctx, id, tenantID, req)
}

func (s *FinanceSettingsService) DeleteTaxNexus(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteTaxNexus(ctx, id, tenantID)
}

func (s *FinanceSettingsService) DeleteOrgReconAccount(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteOrgReconAccount(ctx, id)
}

