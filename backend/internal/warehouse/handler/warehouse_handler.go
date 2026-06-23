package handler

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	whmodels "github.com/swiftai-erp/backend/internal/warehouse/models"
	whesvc "github.com/swiftai-erp/backend/internal/warehouse/service"
	"github.com/swiftai-erp/backend/pkg/response"
)

type WarehouseHandler struct {
	svc *whesvc.WarehouseService
}

func NewWarehouseHandler(svc *whesvc.WarehouseService) *WarehouseHandler {
	return &WarehouseHandler{svc: svc}
}

// ── Products (REQ-WM-002) ──

func (h *WarehouseHandler) CreateProduct(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}

	var req whmodels.CreateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	product, err := h.svc.CreateProduct(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create product failed")
		response.InternalError(c, "create product failed")
		return
	}
	response.Created(c, product)
}

func (h *WarehouseHandler) ListProducts(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	search := c.Query("q")
	products, err := h.svc.ListProducts(c.Request.Context(), tenantID, search)
	if err != nil {
		log.Err(err).Msg("list products failed")
		response.InternalError(c, "list products failed")
		return
	}
	response.OK(c, products)
}

func (h *WarehouseHandler) GetProduct(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	product, err := h.svc.GetProduct(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get product failed")
		response.NotFound(c, "product not found")
		return
	}
	response.OK(c, product)
}

func (h *WarehouseHandler) UpdateProduct(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	var req whmodels.UpdateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateProduct(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update product failed")
		response.InternalError(c, "update product failed")
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *WarehouseHandler) DeleteProduct(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	if err := h.svc.DeleteProduct(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete product failed")
		response.InternalError(c, "delete product failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ── Warehouses ──

func (h *WarehouseHandler) CreateWarehouse(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req whmodels.CreateWarehouseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	warehouse, err := h.svc.CreateWarehouse(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create warehouse failed")
		response.InternalError(c, "create warehouse failed")
		return
	}
	response.Created(c, warehouse)
}

func (h *WarehouseHandler) ListWarehouses(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	warehouses, err := h.svc.ListWarehouses(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list warehouses failed")
		response.InternalError(c, "list warehouses failed")
		return
	}
	response.OK(c, warehouses)
}

func (h *WarehouseHandler) GetWarehouse(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid warehouse id")
		return
	}
	wh, err := h.svc.GetWarehouse(c.Request.Context(), id, tenantID)
	if err != nil {
		log.Err(err).Msg("get warehouse failed")
		response.NotFound(c, "warehouse not found")
		return
	}
	response.OK(c, wh)
}

func (h *WarehouseHandler) UpdateWarehouse(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid warehouse id")
		return
	}
	var req whmodels.UpdateWarehouseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateWarehouse(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update warehouse failed")
		response.InternalError(c, "update warehouse failed")
		return
	}
	wh, err := h.svc.GetWarehouse(c.Request.Context(), id, tenantID)
	if err == nil {
		response.OK(c, wh)
	} else {
		response.OK(c, map[string]string{"status": "updated"})
	}
}

func (h *WarehouseHandler) DeleteWarehouse(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid warehouse id")
		return
	}
	if err := h.svc.DeleteWarehouse(c.Request.Context(), id, tenantID); err != nil {
		log.Err(err).Msg("delete warehouse failed")
		response.InternalError(c, err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ── Stock Movements (REQ-WM-003,004,005) ──

func (h *WarehouseHandler) PostMovement(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	var req whmodels.CreateMovementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	movement, err := h.svc.PostMovement(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("post movement failed")
		response.BadRequest(c, err.Error())
		return
	}
	response.Created(c, movement)
}

func (h *WarehouseHandler) ListStock(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	productID, _ := uuid.Parse(c.Query("product_id"))
	warehouseID, _ := uuid.Parse(c.Query("warehouse_id"))
	binID, _ := uuid.Parse(c.Query("bin_id"))
	dateFrom := c.Query("date_from")
	dateTo := c.Query("date_to")
	groupBySku := c.Query("group_by_sku") == "true"
	items, err := h.svc.ListStock(c.Request.Context(), tenantID, productID, warehouseID, binID, groupBySku, dateFrom, dateTo)
	if err != nil {
		log.Err(err).Msg("list stock failed")
		response.InternalError(c, "list stock failed")
		return
	}
	response.OK(c, items)
}

func (h *WarehouseHandler) ListMovements(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	warehouseID, _ := uuid.Parse(c.Query("warehouse_id"))
	binID, _ := uuid.Parse(c.Query("bin_id"))
	dateFrom := c.Query("date_from")
	dateTo := c.Query("date_to")
	items, err := h.svc.ListMovements(c.Request.Context(), tenantID, warehouseID, binID, dateFrom, dateTo)
	if err != nil {
		log.Err(err).Msg("list movements failed")
		response.InternalError(c, "list movements failed")
		return
	}
	response.OK(c, items)
}

func (h *WarehouseHandler) CreateZone(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req whmodels.CreateZoneRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	zone, err := h.svc.CreateZone(c.Request.Context(), &req)
	if err != nil {
		log.Err(err).Msg("create zone failed")
		response.InternalError(c, "create zone failed")
		return
	}
	response.Created(c, zone)
}

func (h *WarehouseHandler) ListZones(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	whID, _ := uuid.Parse(c.Query("warehouse_id"))
	zones, err := h.svc.ListZones(c.Request.Context(), whID)
	if err != nil {
		log.Err(err).Msg("list zones failed")
		response.InternalError(c, "list zones failed")
		return
	}
	response.OK(c, zones)
}

func (h *WarehouseHandler) CreateBin(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	var req whmodels.CreateBinRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	if req.SiteID == nil && req.ZoneID == nil && req.WarehouseID == nil {
		response.BadRequest(c, "one of warehouse_id, site_id, or zone_id is required")
		return
	}
	if req.SiteID != nil {
		req.ZoneID = nil // clear zone_id if using site_id
	}
	bin, err := h.svc.CreateBin(c.Request.Context(), &req)
	if err != nil {
		log.Err(err).Msg("create bin failed")
		response.InternalError(c, "create bin failed")
		return
	}
	response.Created(c, bin)
}

func (h *WarehouseHandler) ListBins(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	warehouseID, _ := uuid.Parse(c.Query("warehouse_id"))
	siteID, _ := uuid.Parse(c.Query("site_id"))
	zoneID, _ := uuid.Parse(c.Query("zone_id"))
	search := c.Query("q")

	var bins []*whmodels.WarehouseBin
	var listErr error
	if warehouseID != uuid.Nil {
		bins, listErr = h.svc.ListBinsByWarehouse(c.Request.Context(), warehouseID)
	} else if siteID != uuid.Nil {
		bins, listErr = h.svc.ListBinsBySite(c.Request.Context(), siteID)
	} else if zoneID != uuid.Nil {
		bins, listErr = h.svc.ListBins(c.Request.Context(), zoneID)
	} else if search != "" {
		bins, listErr = h.svc.ListAllBins(c.Request.Context(), tenantID, search)
	} else {
		bins, listErr = h.svc.ListAllBins(c.Request.Context(), tenantID, "")
	}
	if listErr != nil {
		log.Err(listErr).Msg("list bins failed")
		response.InternalError(c, "list bins failed")
		return
	}
	response.OK(c, bins)
}

func (h *WarehouseHandler) GetBin(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid bin id")
		return
	}
	bin, err := h.svc.GetBin(c.Request.Context(), id)
	if err != nil {
		log.Err(err).Msg("get bin failed")
		response.NotFound(c, "bin not found")
		return
	}
	response.OK(c, bin)
}

func (h *WarehouseHandler) UpdateBin(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid bin id")
		return
	}
	var req whmodels.UpdateBinRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	if err := h.svc.UpdateBin(c.Request.Context(), id, &req); err != nil {
		log.Err(err).Msg("update bin failed")
		response.InternalError(c, "update bin failed")
		return
	}
	bin, err := h.svc.GetBin(c.Request.Context(), id)
	if err == nil {
		response.OK(c, bin)
	} else {
		response.OK(c, map[string]string{"status": "updated"})
	}
}

func (h *WarehouseHandler) DeleteBin(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid bin id")
		return
	}
	if err := h.svc.DeleteBin(c.Request.Context(), id); err != nil {
		log.Err(err).Msg("delete bin failed")
		response.InternalError(c, "delete bin failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

func (h *WarehouseHandler) ListBarcodes(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	pid, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	barcodes, err := h.svc.ListBarcodes(c.Request.Context(), pid)
	if err != nil {
		log.Err(err).Msg("list barcodes failed")
		response.InternalError(c, "list barcodes failed")
		return
	}
	response.OK(c, barcodes)
}

func (h *WarehouseHandler) CreateBarcode(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	pid, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	var req struct {
		Barcode     string `json:"barcode"`
		BarcodeType string `json:"barcode_type"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}
	barcode, err := h.svc.CreateBarcode(c.Request.Context(), pid, req.Barcode, req.BarcodeType)
	if err != nil {
		log.Err(err).Msg("create barcode failed")
		response.InternalError(c, "create barcode failed")
		return
	}
	response.Created(c, barcode)
}

func (h *WarehouseHandler) DeleteBarcode(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	bid, err := uuid.Parse(c.Param("barcodeId"))
	if err != nil {
		response.BadRequest(c, "invalid barcode id")
		return
	}
	if err := h.svc.DeleteBarcode(c.Request.Context(), bid); err != nil {
		log.Err(err).Msg("delete barcode failed")
		response.InternalError(c, "delete barcode failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ── Photos (REQ-MM-001~010) ──

func (h *WarehouseHandler) ListPhotos(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	pid, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	photos, err := h.svc.ListPhotos(c.Request.Context(), pid)
	if err != nil {
		log.Err(err).Msg("list photos failed")
		response.InternalError(c, "list photos failed")
		return
	}
	response.OK(c, photos)
}

func (h *WarehouseHandler) UploadPhoto(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	pid, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	file, header, err := c.Request.FormFile("photo")
	if err != nil {
		response.BadRequest(c, "no photo file provided")
		return
	}
	defer file.Close()

	// Read entire file content
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		response.InternalError(c, "failed to read file")
		return
	}

	// Detect MIME type from content (first 512 bytes is enough)
	mimeType := http.DetectContentType(fileBytes)

	// Validate image types
	if !strings.HasPrefix(mimeType, "image/") {
		response.BadRequest(c, "only image files are allowed")
		return
	}

	// Save file to disk
	uploadDir := "uploads/products"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		log.Err(err).Msg("create upload dir failed")
		response.InternalError(c, "failed to create upload directory")
		return
	}

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".jpg"
	}
	savedName := uuid.New().String() + ext
	savedPath := filepath.Join(uploadDir, savedName)
	if err := os.WriteFile(savedPath, fileBytes, 0644); err != nil {
		log.Err(err).Msg("save photo file failed")
		response.InternalError(c, "failed to save photo")
		return
	}

	photo, err := h.svc.UploadPhoto(c.Request.Context(), pid, header.Filename, savedPath, len(fileBytes), mimeType)
	if err != nil {
		log.Err(err).Msg("upload photo failed")
		response.InternalError(c, "upload photo failed")
		return
	}
	response.Created(c, photo)
}

func (h *WarehouseHandler) DeletePhoto(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	phid, err := uuid.Parse(c.Param("photoId"))
	if err != nil {
		response.BadRequest(c, "invalid photo id")
		return
	}

	// Get photo info first to find file path
	pid, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid product id")
		return
	}
	photos, err := h.svc.ListPhotos(c.Request.Context(), pid)
	if err == nil {
		for _, p := range photos {
			if p.ID == phid && p.FilePath != "" {
				os.Remove(p.FilePath) // best effort delete file
				break
			}
		}
	}

	if err := h.svc.DeletePhoto(c.Request.Context(), phid); err != nil {
		log.Err(err).Msg("delete photo failed")
		response.InternalError(c, "delete photo failed")
		return
	}
	response.OK(c, map[string]string{"status": "deleted"})
}

// ═══════════════════════════════════════════════════════════════
// Goods Receipt (REQ-IB-005~014)
// ═══════════════════════════════════════════════════════════════

func (h *WarehouseHandler) CreateGR(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}

	var req whmodels.CreateGRRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	gr, err := h.svc.CreateGR(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create gr failed")
		response.InternalError(c, "create gr failed")
		return
	}
	response.Created(c, gr)
}

func (h *WarehouseHandler) ListGRs(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	grs, err := h.svc.ListGRs(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list grs failed")
		response.InternalError(c, "list grs failed")
		return
	}
	response.OK(c, grs)
}

func (h *WarehouseHandler) PostGR(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid gr id")
		return
	}

	if err := h.svc.PostGR(c.Request.Context(), id, tenantID, userID); err != nil {
		log.Err(err).Msg("post gr failed")
		response.InternalError(c, "post gr failed: "+err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "posted"})
}

// ═══════════════════════════════════════════════════════════════
// Outbound Order (REQ-OB-001~018)
// ═══════════════════════════════════════════════════════════════

func (h *WarehouseHandler) CreateOutbound(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}

	var req whmodels.CreateOutboundRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	ob, err := h.svc.CreateOutbound(c.Request.Context(), tenantID, userID, &req)
	if err != nil {
		log.Err(err).Msg("create outbound failed")
		response.InternalError(c, "create outbound failed")
		return
	}
	response.Created(c, ob)
}

func (h *WarehouseHandler) ListOutbound(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	orders, err := h.svc.ListOutbound(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list outbound failed")
		response.InternalError(c, "list outbound failed")
		return
	}
	response.OK(c, orders)
}

func (h *WarehouseHandler) UpdateOutbound(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid order id")
		return
	}

	var req whmodels.CreateOutboundRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	if err := h.svc.UpdateOutbound(c.Request.Context(), id, tenantID, &req); err != nil {
		log.Err(err).Msg("update outbound failed")
		response.InternalError(c, "update outbound failed: "+err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "updated"})
}

func (h *WarehouseHandler) ShipOutbound(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid order id")
		return
	}

	if err := h.svc.ShipOutbound(c.Request.Context(), id, tenantID, userID); err != nil {
		log.Err(err).Msg("ship outbound failed")
		response.InternalError(c, "ship outbound failed: "+err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "issued"})
}

// ═══════════════════════════════════════════════════════════════
// Cycle Count (REQ-CC-001~008)
// ═══════════════════════════════════════════════════════════════

func (h *WarehouseHandler) ReverseOutbound(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid order id")
		return
	}

	if err := h.svc.ReverseOutbound(c.Request.Context(), id, tenantID, userID); err != nil {
		log.Err(err).Msg("reverse outbound failed")
		response.InternalError(c, "reverse outbound failed: "+err.Error())
		return
	}
	response.OK(c, map[string]string{"status": "reversed"})
}

func (h *WarehouseHandler) GetOutboundJournalEntry(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid order id")
		return
	}

	je, err := h.svc.GetOutboundJournalEntry(c.Request.Context(), id, tenantID, userID)
	if err != nil {
		log.Err(err).Msg("get outbound journal failed")
		response.NotFound(c, err.Error())
		return
	}
	response.OK(c, je)
}

func (h *WarehouseHandler) CreateCycleCount(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req whmodels.CreateCycleCountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	cc, err := h.svc.CreateCycleCount(c.Request.Context(), tenantID, &req)
	if err != nil {
		log.Err(err).Msg("create cycle count failed")
		response.InternalError(c, "create cycle count failed")
		return
	}
	response.Created(c, cc)
}

func (h *WarehouseHandler) ListCycleCounts(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	counts, err := h.svc.ListCycleCounts(c.Request.Context(), tenantID)
	if err != nil {
		log.Err(err).Msg("list cycle counts failed")
		response.InternalError(c, "list cycle counts failed")
		return
	}
	response.OK(c, counts)
}

func (h *WarehouseHandler) AISuggestCycleCounts(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	counts, err := h.svc.AISuggestCycleCounts(c.Request.Context(), tenantID, 5)
	if err != nil {
		log.Err(err).Msg("ai suggest cycle counts failed")
		response.InternalError(c, "ai suggest cycle counts failed")
		return
	}
	response.Created(c, counts)
}

// ═══════════════════════════════════════════════════════════════
// Warehouse Tasks (REQ-IO-014~018)
// ═══════════════════════════════════════════════════════════════

func (h *WarehouseHandler) ListTasks(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	status := c.Query("status")
	tasks, err := h.svc.ListTasks(c.Request.Context(), tenantID, status)
	if err != nil {
		log.Err(err).Msg("list tasks failed")
		response.InternalError(c, "list tasks failed")
		return
	}
	response.OK(c, tasks)
}

func (h *WarehouseHandler) CompleteTask(c *gin.Context) {
	if _, err := getTenantID(c); err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}
	userID, err := getUserID(c)
	if err != nil {
		response.BadRequest(c, "missing user context")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid task id")
		return
	}

	if err := h.svc.CompleteTask(c.Request.Context(), id, userID); err != nil {
		log.Err(err).Msg("complete task failed")
		response.InternalError(c, "complete task failed")
		return
	}
	response.OK(c, map[string]string{"status": "completed"})
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" {
		return uuid.Nil, http.ErrNoLocation
	}
	return uuid.Parse(tid)
}

func getUserID(c *gin.Context) (uuid.UUID, error) {
	uid := c.GetString("user_id")
	if uid == "" {
		return uuid.Nil, http.ErrNoLocation
	}
	return uuid.Parse(uid)
}
