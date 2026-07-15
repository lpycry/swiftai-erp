package models

import (
	"github.com/google/uuid"
	"time"
)

// ── Product / Material Master (Section 4) ──

type Product struct {
	ID            uuid.UUID  `json:"id"`
	TenantID      uuid.UUID  `json:"tenant_id"`
	CategoryID    *uuid.UUID `json:"category_id,omitempty"`
	CategoryName  string     `json:"category_name,omitempty"`
	SKU           string     `json:"sku"`
	Barcode       *string    `json:"barcode,omitempty"`
	Name          string     `json:"name"`
	Description   string     `json:"description,omitempty"`
	UnitOfMeasure string     `json:"unit_of_measure"`
	UOMGroup      string     `json:"uom_group,omitempty"`
	BatchTracked  bool       `json:"batch_tracked"`
	SerialTracked bool       `json:"serial_tracked"`
	ShelfLifeDays *int       `json:"shelf_life_days,omitempty"`
	IsSerialized  bool       `json:"is_serialized"`
	IsBlocked     bool       `json:"is_blocked"`
	MaterialType  string     `json:"material_type,omitempty"`
	BlockReason   string     `json:"block_reason,omitempty"`
	// Product Taxability
	TaxCategory              string             `json:"tax_category"`
	TaxRate                  *float64           `json:"tax_rate,omitempty"`
	TaxType                  string             `json:"tax_type"`
	TaxExemptReason          string             `json:"tax_exempt_reason,omitempty"`
	DefaultTaxJurisdictionID *uuid.UUID         `json:"default_tax_jurisdiction_id,omitempty"`
	DimensionLength          *float64           `json:"dimension_length,omitempty"`
	DimensionWidth           *float64           `json:"dimension_width,omitempty"`
	DimensionHeight          *float64           `json:"dimension_height,omitempty"`
	DimensionUnit            string             `json:"dimension_unit"`
	GrossWeight              *float64           `json:"gross_weight,omitempty"`
	NetWeight                *float64           `json:"net_weight,omitempty"`
	WeightUnit               string             `json:"weight_unit"`
	VolumeM3                 *float64           `json:"volume_m3,omitempty"`
	StandardCost             float64            `json:"standard_cost"`
	MovingAvgCost            float64            `json:"moving_avg_cost,omitempty"`
	LastCost                 float64            `json:"last_cost"`
	AvgCost                  float64            `json:"avg_cost"`
	ValuationClass           string             `json:"valuation_class,omitempty"`
	ABCClassification        string             `json:"abc_classification,omitempty"`
	MinStockQty              *float64           `json:"min_stock_qty,omitempty"`
	MaxStockQty              *float64           `json:"max_stock_qty,omitempty"`
	ReorderPoint             *float64           `json:"reorder_point,omitempty"`
	ReorderQty               *float64           `json:"reorder_qty,omitempty"`
	LeadTimeDays             *int               `json:"lead_time_days,omitempty"`
	ProcurementType          string             `json:"procurement_type,omitempty"`
	StorageCondition         string             `json:"storage_condition,omitempty"`
	CountryOfOrigin          string             `json:"country_of_origin,omitempty"`
	HSCode                   string             `json:"hs_code,omitempty"`
	WeightKg                 *float64           `json:"weight_kg,omitempty"`
	IsActive                 bool               `json:"is_active"`
	CreatedAt                time.Time          `json:"created_at"`
	UpdatedAt                time.Time          `json:"updated_at"`
	Photos                   []ProductPhoto     `json:"photos,omitempty"`
	Barcodes                 []ProductBarcode   `json:"barcodes,omitempty"`
	PlantData                []ProductPlantData `json:"plant_data,omitempty"`
	// Production Tab fields
	MRPEnabled            bool   `json:"mrp_enabled"`
	MRPType               string `json:"mrp_type"`
	PhantomAssembly       bool   `json:"phantom_assembly"`
	ProductionLeadTime    *int   `json:"production_lead_time,omitempty"`
	InHouseProductionDays *int   `json:"in_house_production_days,omitempty"`
}

type ProductPlantData struct {
	ID                           uuid.UUID  `json:"id"`
	TenantID                     uuid.UUID  `json:"tenant_id"`
	ProductID                    uuid.UUID  `json:"product_id"`
	SiteID                       uuid.UUID  `json:"site_id"`
	SiteCode                     string     `json:"site_code,omitempty"`
	SiteName                     string     `json:"site_name,omitempty"`
	MRPType                      string     `json:"mrp_type"`
	ProcurementType              string     `json:"procurement_type"`
	SafetyStock                  *float64   `json:"safety_stock,omitempty"`
	ReorderPoint                 *float64   `json:"reorder_point,omitempty"`
	ReorderQty                   *float64   `json:"reorder_qty,omitempty"`
	LeadTimeDays                 *int       `json:"lead_time_days,omitempty"`
	PlanningTimeFenceDays        int        `json:"planning_time_fence_days"`
	DefaultProductionWarehouseID *uuid.UUID `json:"default_production_warehouse_id,omitempty"`
	DefaultReceivingWarehouseID  *uuid.UUID `json:"default_receiving_warehouse_id,omitempty"`
	StandardCost                 *float64   `json:"standard_cost,omitempty"`
	MovingAvgCost                *float64   `json:"moving_avg_cost,omitempty"`
	ValuationClass               string     `json:"valuation_class,omitempty"`
	IsActive                     bool       `json:"is_active"`
}

type CreateProductRequest struct {
	TaxCategory              string     `json:"tax_category,omitempty"`
	TaxRate                  *float64   `json:"tax_rate,omitempty"`
	TaxType                  string     `json:"tax_type,omitempty"`
	TaxExemptReason          string     `json:"tax_exempt_reason,omitempty"`
	DefaultTaxJurisdictionID *string    `json:"default_tax_jurisdiction_id,omitempty"`
	CategoryID               *uuid.UUID `json:"category_id,omitempty"`
	SKU                      string     `json:"sku" binding:"required"`
	Barcode                  string     `json:"barcode,omitempty"`
	Name                     string     `json:"name" binding:"required"`
	Description              string     `json:"description,omitempty"`
	UnitOfMeasure            string     `json:"unit_of_measure" binding:"required"`
	BatchTracked             bool       `json:"batch_tracked"`
	SerialTracked            bool       `json:"serial_tracked"`
	ShelfLifeDays            *int       `json:"shelf_life_days,omitempty"`
	DimensionLength          *float64   `json:"dimension_length,omitempty"`
	DimensionWidth           *float64   `json:"dimension_width,omitempty"`
	DimensionHeight          *float64   `json:"dimension_height,omitempty"`
	DimensionUnit            string     `json:"dimension_unit,omitempty"`
	GrossWeight              *float64   `json:"gross_weight,omitempty"`
	NetWeight                *float64   `json:"net_weight,omitempty"`
	WeightUnit               string     `json:"weight_unit,omitempty"`
	StandardCost             float64    `json:"standard_cost"`
	MovingAvgCost            float64    `json:"moving_avg_cost,omitempty"`
	LastCost                 float64    `json:"last_cost"`
	AvgCost                  float64    `json:"avg_cost"`
	WeightKg                 *float64   `json:"weight_kg,omitempty"`
	VolumeM3                 *float64   `json:"volume_m3,omitempty"`
	ABCClassification        string     `json:"abc_classification,omitempty"`
	ValuationClass           string     `json:"valuation_class,omitempty"`
	HSCode                   string     `json:"hs_code,omitempty"`
	CountryOfOrigin          string     `json:"country_of_origin,omitempty"`
	StorageCondition         string     `json:"storage_condition,omitempty"`
	ProcurementType          string     `json:"procurement_type,omitempty"`
	SafetyStock              *float64   `json:"safety_stock,omitempty"`
	MaxStockQty              *float64   `json:"max_stock_qty,omitempty"`
	ReorderPoint             *float64   `json:"reorder_point,omitempty"`
	ReorderQty               *float64   `json:"reorder_qty,omitempty"`
	LeadTimeDays             *int       `json:"lead_time_days,omitempty"`
	UOMGroup                 string     `json:"uom_group,omitempty"`
	IsSerialized             bool       `json:"is_serialized"`
	MaterialType             string     `json:"material_type,omitempty"`
	// Production Tab fields
	MRPEnabled            bool               `json:"mrp_enabled"`
	MRPType               string             `json:"mrp_type,omitempty"`
	PhantomAssembly       bool               `json:"phantom_assembly"`
	ProductionLeadTime    *int               `json:"production_lead_time,omitempty"`
	InHouseProductionDays *int               `json:"in_house_production_days,omitempty"`
	PlantData             []ProductPlantData `json:"plant_data,omitempty"`
}

type UpdateProductRequest struct {
	TaxCategory              *string    `json:"tax_category,omitempty"`
	TaxRate                  *float64   `json:"tax_rate,omitempty"`
	TaxType                  *string    `json:"tax_type,omitempty"`
	TaxExemptReason          *string    `json:"tax_exempt_reason,omitempty"`
	DefaultTaxJurisdictionID *string    `json:"default_tax_jurisdiction_id,omitempty"`
	CategoryID               *uuid.UUID `json:"category_id,omitempty"`
	Barcode                  string     `json:"barcode,omitempty"`
	Name                     string     `json:"name,omitempty"`
	Description              string     `json:"description,omitempty"`
	UnitOfMeasure            string     `json:"unit_of_measure,omitempty"`
	BatchTracked             *bool      `json:"batch_tracked,omitempty"`
	SerialTracked            *bool      `json:"serial_tracked,omitempty"`
	ShelfLifeDays            *int       `json:"shelf_life_days,omitempty"`
	DimensionLength          *float64   `json:"dimension_length,omitempty"`
	DimensionWidth           *float64   `json:"dimension_width,omitempty"`
	DimensionHeight          *float64   `json:"dimension_height,omitempty"`
	DimensionUnit            *string    `json:"dimension_unit,omitempty"`
	GrossWeight              *float64   `json:"gross_weight,omitempty"`
	NetWeight                *float64   `json:"net_weight,omitempty"`
	WeightUnit               *string    `json:"weight_unit,omitempty"`
	StandardCost             *float64   `json:"standard_cost,omitempty"`
	MovingAvgCost            *float64   `json:"moving_avg_cost,omitempty"`
	LastCost                 *float64   `json:"last_cost,omitempty"`
	AvgCost                  *float64   `json:"avg_cost,omitempty"`
	WeightKg                 *float64   `json:"weight_kg,omitempty"`
	VolumeM3                 *float64   `json:"volume_m3,omitempty"`
	ABCClassification        *string    `json:"abc_classification,omitempty"`
	ValuationClass           *string    `json:"valuation_class,omitempty"`
	HSCode                   *string    `json:"hs_code,omitempty"`
	CountryOfOrigin          *string    `json:"country_of_origin,omitempty"`
	StorageCondition         *string    `json:"storage_condition,omitempty"`
	ProcurementType          *string    `json:"procurement_type,omitempty"`
	SafetyStock              *float64   `json:"safety_stock,omitempty"`
	MaxStockQty              *float64   `json:"max_stock_qty,omitempty"`
	ReorderPoint             *float64   `json:"reorder_point,omitempty"`
	ReorderQty               *float64   `json:"reorder_qty,omitempty"`
	LeadTimeDays             *int       `json:"lead_time_days,omitempty"`
	UOMGroup                 *string    `json:"uom_group,omitempty"`
	IsSerialized             *bool      `json:"is_serialized,omitempty"`
	IsActive                 *bool      `json:"is_active,omitempty"`
	IsBlocked                *bool      `json:"is_blocked,omitempty"`
	// Production Tab fields
	MRPEnabled            *bool              `json:"mrp_enabled,omitempty"`
	MRPType               *string            `json:"mrp_type,omitempty"`
	PhantomAssembly       *bool              `json:"phantom_assembly,omitempty"`
	ProductionLeadTime    *int               `json:"production_lead_time,omitempty"`
	InHouseProductionDays *int               `json:"in_house_production_days,omitempty"`
	MaterialType          *string            `json:"material_type,omitempty"`
	PlantData             []ProductPlantData `json:"plant_data,omitempty"`
}

// ProductPhoto (REQ-MM-001~010)
type ProductPhoto struct {
	ID        uuid.UUID `json:"id"`
	ProductID uuid.UUID `json:"product_id"`
	IsPrimary bool      `json:"is_primary"`
	SortOrder int       `json:"sort_order"`
	FilePath  string    `json:"file_path"`
	FileName  string    `json:"file_name"`
	FileSize  int       `json:"file_size"`
	MimeType  string    `json:"mime_type"`
	AITags    *string   `json:"ai_tags,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type ProductBarcode struct {
	ID          uuid.UUID `json:"id"`
	ProductID   uuid.UUID `json:"product_id"`
	Barcode     string    `json:"barcode"`
	BarcodeType string    `json:"barcode_type"`
	IsPrimary   bool      `json:"is_primary"`
	CreatedAt   time.Time `json:"created_at"`
}

// ── Warehouse (Section 5) ──

type Warehouse struct {
	ID             uuid.UUID  `json:"id"`
	TenantID       uuid.UUID  `json:"tenant_id"`
	OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
	OrgCode        string     `json:"org_code,omitempty"`
	OrgName        string     `json:"org_name,omitempty"`
	SiteID         *uuid.UUID `json:"site_id,omitempty"`
	SiteCode       string     `json:"site_code,omitempty"`
	SiteName       string     `json:"site_name,omitempty"`
	Code           string     `json:"code"`
	Name           string     `json:"name"`
	Address        string     `json:"address,omitempty"`
	WarehouseType  string     `json:"warehouse_type"`
	Timezone       string     `json:"timezone"`
	IsActive       bool       `json:"is_active"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type CreateWarehouseRequest struct {
	Code           string     `json:"code" binding:"required"`
	Name           string     `json:"name" binding:"required"`
	Address        string     `json:"address,omitempty"`
	WarehouseType  string     `json:"warehouse_type,omitempty"`
	OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
	SiteID         *uuid.UUID `json:"site_id,omitempty"`
}

type UpdateWarehouseRequest struct {
	Code           *string    `json:"code,omitempty"`
	Name           *string    `json:"name,omitempty"`
	Address        *string    `json:"address,omitempty"`
	OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
	SiteID         *uuid.UUID `json:"site_id,omitempty"`
	IsActive       *bool      `json:"is_active,omitempty"`
}

type WarehouseZone struct {
	ID               uuid.UUID `json:"id"`
	WarehouseID      uuid.UUID `json:"warehouse_id"`
	Code             string    `json:"code"`
	Name             string    `json:"name"`
	ZoneType         string    `json:"zone_type"`
	Description      string    `json:"description,omitempty"`
	CapacityWeightKg *float64  `json:"capacity_weight_kg,omitempty"`
	CapacityVolumeM3 *float64  `json:"capacity_volume_m3,omitempty"`
	TemperatureMin   *float64  `json:"temperature_min,omitempty"`
	TemperatureMax   *float64  `json:"temperature_max,omitempty"`
	SortOrder        int       `json:"sort_order"`
	IsActive         bool      `json:"is_active"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type CreateZoneRequest struct {
	WarehouseID uuid.UUID `json:"warehouse_id" binding:"required"`
	Code        string    `json:"code" binding:"required"`
	Name        string    `json:"name" binding:"required"`
	ZoneType    string    `json:"zone_type"`
}

// Bin
// SiteID refers to the sites table (org unit) — use this OR ZoneID
type WarehouseBin struct {
	ID            uuid.UUID  `json:"id"`
	ZoneID        *uuid.UUID `json:"zone_id,omitempty"`
	SiteID        *uuid.UUID `json:"site_id,omitempty"`
	WarehouseID   *uuid.UUID `json:"warehouse_id,omitempty"`
	WarehouseCode string     `json:"warehouse_code,omitempty"`
	WarehouseName string     `json:"warehouse_name,omitempty"`
	Code          string     `json:"code"`
	Name          string     `json:"name,omitempty"`
	Barcode       string     `json:"barcode,omitempty"`
	BinType       string     `json:"bin_type"`
	BinStatus     string     `json:"bin_status"`
	MaxWeightKg   *float64   `json:"max_weight_kg,omitempty"`
	MaxVolumeM3   *float64   `json:"max_volume_m3,omitempty"`
	IsActive      bool       `json:"is_active"`
	SiteCode      string     `json:"site_code,omitempty"`
	SiteName      string     `json:"site_name,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

type CreateBinRequest struct {
	ZoneID      *uuid.UUID `json:"zone_id,omitempty"`
	SiteID      *uuid.UUID `json:"site_id,omitempty"`
	WarehouseID *uuid.UUID `json:"warehouse_id,omitempty"`
	Code        string     `json:"code" binding:"required"`
	Name        string     `json:"name"`
	Barcode     string     `json:"barcode,omitempty"`
	MaxWeightKg *float64   `json:"max_weight_kg,omitempty"`
	MaxVolumeM3 *float64   `json:"max_volume_m3,omitempty"`
	IsActive    *bool      `json:"is_active,omitempty"`
}

type UpdateBinRequest struct {
	Name        string   `json:"name,omitempty"`
	Barcode     string   `json:"barcode,omitempty"`
	MaxWeightKg *float64 `json:"max_weight_kg,omitempty"`
	MaxVolumeM3 *float64 `json:"max_volume_m3,omitempty"`
	IsActive    *bool    `json:"is_active,omitempty"`
}

// ── Stock ──

type StockItem struct {
	ID                uuid.UUID  `json:"id"`
	TenantID          uuid.UUID  `json:"tenant_id"`
	ProductID         uuid.UUID  `json:"product_id"`
	ProductSKU        string     `json:"product_sku,omitempty"`
	ProductName       string     `json:"product_name,omitempty"`
	WarehouseID       uuid.UUID  `json:"warehouse_id"`
	WarehouseName     string     `json:"warehouse_name,omitempty"`
	BinID             *uuid.UUID `json:"bin_id,omitempty"`
	BinCode           string     `json:"bin_code,omitempty"`
	BatchID           *uuid.UUID `json:"batch_id,omitempty"`
	BatchNo           string     `json:"batch_no,omitempty"`
	LotNo             string     `json:"lot_no,omitempty"`
	QuantityOnHand    float64    `json:"quantity_on_hand"`
	QuantityReserved  float64    `json:"quantity_reserved"`
	QuantityInTransit float64    `json:"quantity_in_transit"`
	UnitCost          float64    `json:"unit_cost"`
	TotalCost         float64    `json:"total_cost"`
	LastMovementAt    *time.Time `json:"last_movement_at,omitempty"`
	LastCountedAt     *time.Time `json:"last_counted_at,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type StockMovement struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	TransactionType string     `json:"transaction_type"`
	ReferenceType   string     `json:"reference_type,omitempty"`
	ReferenceID     *uuid.UUID `json:"reference_id,omitempty"`
	ReferenceNo     string     `json:"reference_no,omitempty"`
	ProductID       uuid.UUID  `json:"product_id"`
	ProductSKU      string     `json:"product_sku,omitempty"`
	ProductName     string     `json:"product_name,omitempty"`
	WarehouseID     uuid.UUID  `json:"warehouse_id"`
	WarehouseName   string     `json:"warehouse_name,omitempty"`
	BinID           *uuid.UUID `json:"bin_id,omitempty"`
	BinCode         string     `json:"bin_code,omitempty"`
	BatchID         *uuid.UUID `json:"batch_id,omitempty"`
	BatchNo         string     `json:"batch_no,omitempty"`
	Quantity        float64    `json:"quantity"`
	UnitCost        float64    `json:"unit_cost"`
	TotalCost       float64    `json:"total_cost"`
	ToWarehouseID   *uuid.UUID `json:"to_warehouse_id,omitempty"`
	ToWarehouseName string     `json:"to_warehouse_name,omitempty"`
	ToBinID         *uuid.UUID `json:"to_bin_id,omitempty"`
	ToBinCode       string     `json:"to_bin_code,omitempty"`
	Status          string     `json:"status"`
	Description     string     `json:"description,omitempty"`
	CreatedBy       uuid.UUID  `json:"created_by"`
	CreatedAt       time.Time  `json:"created_at"`
	PostedAt        *time.Time `json:"posted_at,omitempty"`
	PostedBy        *uuid.UUID `json:"posted_by,omitempty"`
}

type CreateMovementRequest struct {
	TransactionType string     `json:"transaction_type" binding:"required,oneof=goods_receipt goods_issue transfer adjustment"`
	ReferenceType   string     `json:"reference_type,omitempty"`
	ReferenceID     *uuid.UUID `json:"reference_id,omitempty"`
	ReferenceNo     string     `json:"reference_no,omitempty"`
	ProductID       uuid.UUID  `json:"product_id" binding:"required"`
	WarehouseID     uuid.UUID  `json:"warehouse_id" binding:"required"`
	BinID           *uuid.UUID `json:"bin_id,omitempty"`
	BatchID         *uuid.UUID `json:"batch_id,omitempty"`
	Quantity        float64    `json:"quantity" binding:"required"`
	UnitCost        float64    `json:"unit_cost"`
	TotalCost       float64    `json:"total_cost"`
	ToWarehouseID   *uuid.UUID `json:"to_warehouse_id,omitempty"`
	ToBinID         *uuid.UUID `json:"to_bin_id,omitempty"`
	Description     string     `json:"description,omitempty"`
}

type Batch struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	ProductID       uuid.UUID  `json:"product_id"`
	BatchNo         string     `json:"batch_no"`
	ManufactureDate *time.Time `json:"manufacture_date,omitempty"`
	ExpiryDate      *time.Time `json:"expiry_date,omitempty"`
	ShelfLifeDays   *int       `json:"shelf_life_days,omitempty"`
	ReceivedDate    time.Time  `json:"received_date"`
	SupplierID      *uuid.UUID `json:"supplier_id,omitempty"`
	IsBlocked       bool       `json:"is_blocked"`
	BlockReason     string     `json:"block_reason,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type UOMConversion struct {
	ID             uuid.UUID `json:"id"`
	TenantID       uuid.UUID `json:"tenant_id"`
	ProductID      uuid.UUID `json:"product_id"`
	FromUOM        string    `json:"from_uom"`
	ToUOM          string    `json:"to_uom"`
	ConversionRate float64   `json:"conversion_rate"`
	IsActive       bool      `json:"is_active"`
}

// ── New WMS Entities (SRD v1.0) ──

// ── New Request Types ──

type CreateGRRequest struct {
	ReceiptType  string       `json:"receipt_type"`
	ReferenceNo  string       `json:"reference_no,omitempty"`
	WarehouseID  uuid.UUID    `json:"warehouse_id" binding:"required"`
	SupplierName string       `json:"supplier_name,omitempty"`
	ReceiptDate  time.Time    `json:"receipt_date,omitempty"`
	Lines        []GRLineItem `json:"lines" binding:"required"`
}

type GRLineItem struct {
	ProductID   uuid.UUID  `json:"product_id" binding:"required"`
	ReceivedQty float64    `json:"received_qty" binding:"required"`
	UnitCost    float64    `json:"unit_cost"`
	BatchNo     string     `json:"batch_no,omitempty"`
	ExpiryDate  *time.Time `json:"expiry_date,omitempty"`
}

type GoodsReceipt struct {
	ID            uuid.UUID          `json:"id"`
	TenantID      uuid.UUID          `json:"tenant_id"`
	GRNo          string             `json:"gr_no"`
	ReceiptType   string             `json:"receipt_type"`
	ReferenceNo   string             `json:"reference_no,omitempty"`
	WarehouseID   uuid.UUID          `json:"warehouse_id"`
	WarehouseName string             `json:"warehouse_name,omitempty"`
	SupplierName  string             `json:"supplier_name,omitempty"`
	ReceiptDate   time.Time          `json:"receipt_date"`
	Status        string             `json:"status"`
	Notes         string             `json:"notes,omitempty"`
	CreatedBy     uuid.UUID          `json:"created_by"`
	CreatedAt     time.Time          `json:"created_at"`
	PostedAt      *time.Time         `json:"posted_at,omitempty"`
	PostedBy      *uuid.UUID         `json:"posted_by,omitempty"`
	Lines         []GoodsReceiptLine `json:"lines,omitempty"`
}

type GoodsReceiptLine struct {
	ID          uuid.UUID  `json:"id"`
	GRID        uuid.UUID  `json:"gr_id"`
	ProductID   uuid.UUID  `json:"product_id"`
	ExpectedQty float64    `json:"expected_qty,omitempty"`
	ReceivedQty float64    `json:"received_qty"`
	AcceptedQty *float64   `json:"accepted_qty,omitempty"`
	RejectedQty float64    `json:"rejected_qty"`
	UnitCost    float64    `json:"unit_cost"`
	TotalCost   float64    `json:"total_cost"`
	BatchNo     string     `json:"batch_no,omitempty"`
	ExpiryDate  *time.Time `json:"expiry_date,omitempty"`
}

type CreateOutboundRequest struct {
	OrderType    string             `json:"order_type"`
	ReferenceNo  string             `json:"reference_no,omitempty"`
	WarehouseID  *uuid.UUID         `json:"warehouse_id,omitempty"`
	CustomerName string             `json:"customer_name,omitempty"`
	Lines        []OutboundLineItem `json:"lines" binding:"required"`
}

type OutboundLineItem struct {
	ProductID   uuid.UUID  `json:"product_id" binding:"required"`
	WarehouseID *uuid.UUID `json:"warehouse_id,omitempty"`
	BinID       *uuid.UUID `json:"bin_id,omitempty"`
	OrderedQty  float64    `json:"ordered_qty" binding:"required"`
}

type OutboundOrder struct {
	ID            uuid.UUID           `json:"id"`
	TenantID      uuid.UUID           `json:"tenant_id"`
	OrderNo       string              `json:"order_no"`
	OrderType     string              `json:"order_type"`
	ReferenceNo   string              `json:"reference_no,omitempty"`
	WarehouseID   uuid.UUID           `json:"warehouse_id"`
	WarehouseName string              `json:"warehouse_name,omitempty"`
	CustomerName  string              `json:"customer_name,omitempty"`
	Status        string              `json:"status"`
	Priority      string              `json:"priority"`
	Notes         string              `json:"notes,omitempty"`
	CreatedBy     uuid.UUID           `json:"created_by"`
	CreatedAt     time.Time           `json:"created_at"`
	ShippedAt     *time.Time          `json:"shipped_at,omitempty"`
	DeliveredAt   *time.Time          `json:"delivered_at,omitempty"`
	GLJEID        *uuid.UUID          `json:"gl_je_id,omitempty"`
	IsReversed    bool                `json:"is_reversed"`
	ReversedAt    *time.Time          `json:"reversed_at,omitempty"`
	Lines         []OutboundOrderLine `json:"lines,omitempty"`
}

type OutboundOrderLine struct {
	ID            uuid.UUID  `json:"id"`
	OrderID       uuid.UUID  `json:"order_id"`
	ProductID     uuid.UUID  `json:"product_id"`
	WarehouseID   *uuid.UUID `json:"warehouse_id,omitempty"`
	WarehouseName string     `json:"warehouse_name,omitempty"`
	BinID         *uuid.UUID `json:"bin_id,omitempty"`
	BinCode       string     `json:"bin_code,omitempty"`
	ProductSKU    string     `json:"product_sku,omitempty"`
	ProductName   string     `json:"product_name,omitempty"`
	OrderedQty    float64    `json:"ordered_qty"`
	PickedQty     float64    `json:"picked_qty"`
	ShippedQty    float64    `json:"shipped_qty"`
	UnitCost      float64    `json:"unit_cost,omitempty"`
	TotalCost     float64    `json:"total_cost,omitempty"`
	BatchNo       string     `json:"batch_no,omitempty"`
}

type CreateCycleCountRequest struct {
	CountType   string     `json:"count_type"`
	WarehouseID uuid.UUID  `json:"warehouse_id"`
	ZoneID      *uuid.UUID `json:"zone_id,omitempty"`
	BinID       *uuid.UUID `json:"bin_id,omitempty"`
	ProductID   *uuid.UUID `json:"product_id,omitempty"`
}

type CycleCount struct {
	ID          uuid.UUID  `json:"id"`
	TenantID    uuid.UUID  `json:"tenant_id"`
	CountNo     string     `json:"count_no"`
	CountType   string     `json:"count_type"`
	WarehouseID uuid.UUID  `json:"warehouse_id"`
	ZoneID      *uuid.UUID `json:"zone_id,omitempty"`
	BinID       *uuid.UUID `json:"bin_id,omitempty"`
	ProductID   *uuid.UUID `json:"product_id,omitempty"`
	ProductName string     `json:"product_name,omitempty"`
	BinCode     string     `json:"bin_code,omitempty"`
	Status      string     `json:"status"`
	AISuggested bool       `json:"ai_suggested"`
	CountedBy   *uuid.UUID `json:"counted_by,omitempty"`
	VerifiedBy  *uuid.UUID `json:"verified_by,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// ── Warehouse Task (REQ-IO-014~018) ──

type WarehouseTask struct {
	ID              uuid.UUID  `json:"id"`
	TenantID        uuid.UUID  `json:"tenant_id"`
	TaskType        string     `json:"task_type"`
	ReferenceType   string     `json:"reference_type,omitempty"`
	ReferenceID     *uuid.UUID `json:"reference_id,omitempty"`
	ProductID       *uuid.UUID `json:"product_id,omitempty"`
	ProductName     string     `json:"product_name,omitempty"`
	FromWarehouseID *uuid.UUID `json:"from_warehouse_id,omitempty"`
	FromBinID       *uuid.UUID `json:"from_bin_id,omitempty"`
	ToWarehouseID   *uuid.UUID `json:"to_warehouse_id,omitempty"`
	ToBinID         *uuid.UUID `json:"to_bin_id,omitempty"`
	Quantity        float64    `json:"quantity"`
	UOM             string     `json:"uom"`
	BatchNo         string     `json:"batch_no,omitempty"`
	Status          string     `json:"status"`
	Priority        string     `json:"priority"`
	AssignedTo      *uuid.UUID `json:"assigned_to,omitempty"`
	Notes           string     `json:"notes,omitempty"`
	CreatedBy       uuid.UUID  `json:"created_by"`
	CreatedAt       time.Time  `json:"created_at"`
}

type CreateTaskRequest struct {
	TaskType        string     `json:"task_type" binding:"required"`
	ProductID       *uuid.UUID `json:"product_id,omitempty"`
	FromWarehouseID *uuid.UUID `json:"from_warehouse_id,omitempty"`
	FromBinID       *uuid.UUID `json:"from_bin_id,omitempty"`
	ToWarehouseID   *uuid.UUID `json:"to_warehouse_id,omitempty"`
	ToBinID         *uuid.UUID `json:"to_bin_id,omitempty"`
	Quantity        float64    `json:"quantity"`
	Notes           string     `json:"notes,omitempty"`
}
