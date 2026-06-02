package service

import (
	"context"

	"github.com/google/uuid"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
	salesrepo "github.com/swiftai-erp/backend/internal/sales/repository"
)

type SalesService struct {
	repo *salesrepo.SalesRepo
}

func NewSalesService(repo *salesrepo.SalesRepo) *SalesService {
	return &SalesService{repo: repo}
}

// ── Customers ──

func (s *SalesService) ListCustomers(ctx context.Context, tenantID uuid.UUID, query, status string) ([]*salesmodels.Customer, error) {
	return s.repo.ListCustomers(ctx, tenantID, query, status)
}

func (s *SalesService) GetCustomer(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.Customer, error) {
	return s.repo.GetCustomer(ctx, id, tenantID)
}

func (s *SalesService) CreateCustomer(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateCustomerRequest) (*salesmodels.Customer, error) {
	return s.repo.CreateCustomer(ctx, tenantID, req)
}

func (s *SalesService) UpdateCustomer(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateCustomerRequest) error {
	return s.repo.UpdateCustomer(ctx, id, tenantID, req)
}

func (s *SalesService) DeleteCustomer(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteCustomer(ctx, id, tenantID)
}

// ── Customer Certificates ──

func (s *SalesService) ListCertificates(ctx context.Context, customerID, tenantID uuid.UUID) ([]*salesmodels.CustomerCertificate, error) {
	return s.repo.ListCertificates(ctx, customerID, tenantID)
}

func (s *SalesService) UploadCertificate(ctx context.Context, cert *salesmodels.CustomerCertificate) error {
	return s.repo.UploadCertificate(ctx, cert)
}

func (s *SalesService) DeleteCertificate(ctx context.Context, id, customerID, tenantID uuid.UUID) error {
	return s.repo.DeleteCertificate(ctx, id, customerID, tenantID)
}

// ── Material Prices ──

func (s *SalesService) ListMaterialPrices(ctx context.Context, tenantID uuid.UUID, productID uuid.UUID, activeOnly bool) ([]*salesmodels.MaterialPrice, error) {
	return s.repo.ListMaterialPrices(ctx, tenantID, productID, activeOnly)
}

func (s *SalesService) GetMaterialPrice(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.MaterialPrice, error) {
	return s.repo.GetMaterialPrice(ctx, id, tenantID)
}

func (s *SalesService) CreateMaterialPrice(ctx context.Context, tenantID uuid.UUID, req *salesmodels.CreateMaterialPriceRequest) (*salesmodels.MaterialPrice, error) {
	return s.repo.CreateMaterialPrice(ctx, tenantID, req)
}

func (s *SalesService) UpdateMaterialPrice(ctx context.Context, id, tenantID uuid.UUID, req *salesmodels.UpdateMaterialPriceRequest) error {
	return s.repo.UpdateMaterialPrice(ctx, id, tenantID, req)
}

func (s *SalesService) DeleteMaterialPrice(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.repo.DeleteMaterialPrice(ctx, id, tenantID)
}
