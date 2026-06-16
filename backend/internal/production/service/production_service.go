package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	prorepo "github.com/swiftai-erp/backend/internal/production/repository"
	prodmodels "github.com/swiftai-erp/backend/internal/production/models"
)

type ProductionService struct {
	db     *pgxpool.Pool
	bomRepo  *prorepo.BOMRepo
	wcRepo   *prorepo.WorkCenterRepo
	rtRepo   *prorepo.RoutingTemplateRepo
	opRepo   *prorepo.TemplateOperationRepo
	poRepo   *prorepo.ProductionOrderRepo
}

func NewProductionService(db *pgxpool.Pool, bomRepo *prorepo.BOMRepo,
	wcRepo *prorepo.WorkCenterRepo, rtRepo *prorepo.RoutingTemplateRepo,
	opRepo *prorepo.TemplateOperationRepo,
	poRepo *prorepo.ProductionOrderRepo) *ProductionService {
	return &ProductionService{
		db: db, bomRepo: bomRepo, wcRepo: wcRepo,
		rtRepo: rtRepo, opRepo: opRepo, poRepo: poRepo,
	}
}

// ── BOM ──
func (s *ProductionService) CreateBOM(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.CreateBOMRequest) (*prodmodels.BOMHeader, error) {
	return s.bomRepo.Create(ctx, tenantID, userID, req)
}
func (s *ProductionService) GetBOM(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.BOMHeader, error) {
	return s.bomRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListBOMs(ctx context.Context, tenantID uuid.UUID, materialID *uuid.UUID, status string) ([]*prodmodels.BOMHeader, error) {
	return s.bomRepo.List(ctx, tenantID, materialID, status)
}
func (s *ProductionService) UpdateBOM(ctx context.Context, id, tenantID, userID uuid.UUID, req *prodmodels.UpdateBOMRequest) error {
	return s.bomRepo.Update(ctx, id, tenantID, req, userID)
}
func (s *ProductionService) DeleteBOM(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	return s.bomRepo.Delete(ctx, id, tenantID, userID)
}
func (s *ProductionService) AddBOMItem(ctx context.Context, bomID, tenantID uuid.UUID, req *prodmodels.CreateBOMItemRequest) (*prodmodels.BOMItem, error) {
	req.BOMID = bomID
	return s.bomRepo.AddItem(ctx, tenantID, req)
}
func (s *ProductionService) UpdateBOMItem(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateBOMItemRequest) error {
	return s.bomRepo.UpdateItem(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteBOMItem(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.bomRepo.DeleteItem(ctx, id, tenantID)
}
func (s *ProductionService) ExplodeBOM(ctx context.Context, tenantID uuid.UUID, req *prodmodels.ExplodeRequest) ([]*prodmodels.ExplosionItem, error) {
	return s.bomRepo.Explode(ctx, tenantID, req)
}

// ── Work Center ──
func (s *ProductionService) CreateWorkCenter(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateWorkCenterRequest) (*prodmodels.WorkCenter, error) {
	return s.wcRepo.Create(ctx, tenantID, req)
}
func (s *ProductionService) GetWorkCenter(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.WorkCenter, error) {
	return s.wcRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListWorkCenters(ctx context.Context, tenantID uuid.UUID) ([]*prodmodels.WorkCenter, error) {
	return s.wcRepo.List(ctx, tenantID)
}
func (s *ProductionService) UpdateWorkCenter(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateWorkCenterRequest) error {
	return s.wcRepo.Update(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteWorkCenter(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.wcRepo.Delete(ctx, id, tenantID)
}

// ── Routing Template ──
func (s *ProductionService) CreateRoutingTemplate(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateRoutingTemplateRequest) (*prodmodels.RoutingTemplate, error) {
	return s.rtRepo.Create(ctx, tenantID, req)
}
func (s *ProductionService) GetRoutingTemplate(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.RoutingTemplate, error) {
	return s.rtRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListRoutingTemplates(ctx context.Context, tenantID uuid.UUID) ([]*prodmodels.RoutingTemplate, error) {
	return s.rtRepo.List(ctx, tenantID)
}
func (s *ProductionService) UpdateRoutingTemplate(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateRoutingTemplateRequest) error {
	return s.rtRepo.Update(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteRoutingTemplate(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.rtRepo.Delete(ctx, id, tenantID)
}

// ── Template Operation ──
func (s *ProductionService) CreateTemplateOperation(ctx context.Context, tenantID uuid.UUID, req *prodmodels.CreateTemplateOperationRequest) (*prodmodels.TemplateOperation, error) {
	return s.opRepo.Create(ctx, tenantID, req)
}
func (s *ProductionService) UpdateTemplateOperation(ctx context.Context, id, tenantID uuid.UUID, req *prodmodels.UpdateTemplateOperationRequest) error {
	return s.opRepo.Update(ctx, id, tenantID, req)
}
func (s *ProductionService) DeleteTemplateOperation(ctx context.Context, id, tenantID uuid.UUID) error {
	return s.opRepo.Delete(ctx, id, tenantID)
}

// ── Production Order ──
func (s *ProductionService) CreateProductionOrder(ctx context.Context, tenantID, userID uuid.UUID, req *prodmodels.CreateProductionOrderRequest) (*prodmodels.ProductionOrder, error) {
	return s.poRepo.Create(ctx, tenantID, userID, req)
}
func (s *ProductionService) GetProductionOrder(ctx context.Context, id, tenantID uuid.UUID) (*prodmodels.ProductionOrder, error) {
	return s.poRepo.GetByID(ctx, id, tenantID)
}
func (s *ProductionService) ListProductionOrders(ctx context.Context, tenantID uuid.UUID, materialID *uuid.UUID, status string) ([]*prodmodels.ProductionOrder, error) {
	return s.poRepo.List(ctx, tenantID, materialID, status)
}
func (s *ProductionService) UpdateProductionOrder(ctx context.Context, id, tenantID, userID uuid.UUID, req *prodmodels.UpdateProductionOrderRequest) error {
	return s.poRepo.Update(ctx, id, tenantID, req, userID)
}
func (s *ProductionService) DeleteProductionOrder(ctx context.Context, id, tenantID, userID uuid.UUID) error {
	return s.poRepo.Delete(ctx, id, tenantID, userID)
}

// GetPORoutingInfo returns routing template info for a production order via its BOM
func (s *ProductionService) GetPORoutingInfo(ctx context.Context, poID, tenantID uuid.UUID) (*prodmodels.RoutingTemplate, error) {
	po, err := s.poRepo.GetByID(ctx, poID, tenantID)
	if err != nil {
		return nil, err
	}
	// BOM is optional; if no BOM, return nil
	if po.BOMID == nil {
		return nil, nil
	}
	// Get BOM header
	bom, err := s.bomRepo.GetByID(ctx, *po.BOMID, tenantID)
	if err != nil {
		return nil, err
	}
	// If BOM has no routing template, return nil
	if bom.RoutingTemplateID == nil {
		return nil, nil
	}
	// Get routing template
	return s.rtRepo.GetByID(ctx, *bom.RoutingTemplateID, tenantID)
}

var _ = time.Now
