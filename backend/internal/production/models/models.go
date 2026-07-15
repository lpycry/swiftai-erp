package models

import (
	"time"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------
// BOM Usage constants
// ---------------------------------------------------------------

const (
	BOMUsageProduction  = "PRODUCTION"
	BOMUsageEngineering = "ENGINEERING"
	BOMUsageSales       = "SALES"
)

var ValidBOMUsages = map[string]bool{
	BOMUsageProduction:  true,
	BOMUsageEngineering: true,
	BOMUsageSales:       true,
}

// ---------------------------------------------------------------
// BOM Header
// ---------------------------------------------------------------

type BOMHeader struct {
	BOMID               uuid.UUID  `json:"bom_id"`
	TenantID            uuid.UUID  `json:"tenant_id"`
	MaterialID          uuid.UUID  `json:"material_id"`
	MaterialName        string     `json:"material_name,omitempty"`
	MaterialSKU         string     `json:"material_sku,omitempty"`
	BOMVersion          string     `json:"bom_version"`
	BOMUsage            string     `json:"bom_usage"`
	Status              string     `json:"status"`
	BaseQty             float64    `json:"base_qty"`
	ValidFrom           time.Time  `json:"valid_from"`
	ValidTo             time.Time  `json:"valid_to"`
	Description         string     `json:"description,omitempty"`
	IsActive            bool       `json:"is_active"`
	RoutingTemplateID   *uuid.UUID `json:"routing_template_id,omitempty"`
	RoutingTemplateName string     `json:"routing_template_name,omitempty"`
	CreatedBy           *uuid.UUID `json:"created_by,omitempty"`
	UpdatedBy           *uuid.UUID `json:"updated_by,omitempty"`
	CreatedAt           time.Time  `json:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at"`
	Items               []BOMItem  `json:"items,omitempty"`
}

type CreateBOMRequest struct {
	MaterialID        uuid.UUID              `json:"material_id" binding:"required"`
	BOMVersion        string                 `json:"bom_version" binding:"required"`
	BOMUsage          string                 `json:"bom_usage,omitempty"`
	BaseQty           float64                `json:"base_qty,omitempty"`
	ValidFrom         string                 `json:"valid_from,omitempty"`
	ValidTo           string                 `json:"valid_to,omitempty"`
	Description       string                 `json:"description,omitempty"`
	IsActive          bool                   `json:"is_active"`
	RoutingTemplateID *uuid.UUID             `json:"routing_template_id,omitempty"`
	Items             []CreateBOMItemRequest `json:"items" binding:"required,min=1,dive"`
}

type UpdateBOMRequest struct {
	BOMVersion        *string    `json:"bom_version,omitempty"`
	BOMUsage          *string    `json:"bom_usage,omitempty"`
	BaseQty           *float64   `json:"base_qty,omitempty"`
	ValidFrom         *string    `json:"valid_from,omitempty"`
	ValidTo           *string    `json:"valid_to,omitempty"`
	Description       *string    `json:"description,omitempty"`
	IsActive          *bool      `json:"is_active,omitempty"`
	RoutingTemplateID *uuid.UUID `json:"routing_template_id,omitempty"`

	// For BOM item sync during BOM update
	Items []CreateBOMItemRequest `json:"items,omitempty"`
}

// ---------------------------------------------------------------
// BOM Item
// ---------------------------------------------------------------

type BOMItem struct {
	ItemID        uuid.UUID  `json:"item_id"`
	BOMID         uuid.UUID  `json:"bom_id"`
	ItemPosition  int        `json:"item_position"`
	ComponentID   uuid.UUID  `json:"component_id"`
	ComponentName string     `json:"component_name,omitempty"`
	ComponentSKU  string     `json:"component_sku,omitempty"`
	Quantity      float64    `json:"quantity"`
	UnitOfMeasure string     `json:"unit_of_measure"`
	ScrapFactor   float64    `json:"scrap_factor"`
	IsPhantomItem bool       `json:"is_phantom_item"`
	ValidFrom     *time.Time `json:"valid_from,omitempty"`
	ValidTo       *time.Time `json:"valid_to,omitempty"`
	Remark        string     `json:"remark,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

type CreateBOMItemRequest struct {
	ItemID        uuid.UUID `json:"item_id,omitempty"`
	BOMID         uuid.UUID `json:"bom_id,omitempty"`
	ItemPosition  int       `json:"item_position,omitempty"`
	ComponentID   uuid.UUID `json:"component_id" binding:"required"`
	Quantity      float64   `json:"quantity" binding:"required,min=0.0001"`
	UnitOfMeasure string    `json:"unit_of_measure,omitempty"`
	ScrapFactor   float64   `json:"scrap_factor,omitempty"`
	IsPhantomItem bool      `json:"is_phantom_item,omitempty"`
	Remark        string    `json:"remark,omitempty"`
}

type UpdateBOMItemRequest struct {
	ItemPosition  *int       `json:"item_position,omitempty"`
	ComponentID   *uuid.UUID `json:"component_id,omitempty"`
	Quantity      *float64   `json:"quantity,omitempty"`
	UnitOfMeasure *string    `json:"unit_of_measure,omitempty"`
	ScrapFactor   *float64   `json:"scrap_factor,omitempty"`
	IsPhantomItem *bool      `json:"is_phantom_item,omitempty"`
	Remark        *string    `json:"remark,omitempty"`
}

// ---------------------------------------------------------------
// BOM Explosion
// ---------------------------------------------------------------

type ExplodeRequest struct {
	MaterialID     uuid.UUID `json:"material_id" binding:"required"`
	BOMVersion     string    `json:"bom_version,omitempty"`
	RequirementQty float64   `json:"requirement_qty,omitempty"`
	ExplosionType  string    `json:"explosion_type" binding:"required,oneof=single multi"`
}

type ExplosionItem struct {
	Level         int       `json:"level"`
	ComponentID   uuid.UUID `json:"component_id"`
	ComponentName string    `json:"component_name,omitempty"`
	ComponentSKU  string    `json:"component_sku,omitempty"`
	Quantity      float64   `json:"quantity"`
	UnitOfMeasure string    `json:"unit_of_measure"`
	ScrapFactor   float64   `json:"scrap_factor"`
	IsPhantomItem bool      `json:"is_phantom_item"`
	BOMVersion    string    `json:"bom_version,omitempty"`
}

// ---------------------------------------------------------------
// Master Production Schedule
// ---------------------------------------------------------------

type MPSRunRequest struct {
	SiteID                   *uuid.UUID `json:"site_id,omitempty"`
	PlanningMode             string     `json:"planning_mode,omitempty"`
	PlanningTimeFenceEnabled bool       `json:"planning_time_fence_enabled"`
	PlanningTimeFenceDays    int        `json:"planning_time_fence_days,omitempty"`
	RunMRPAfterMPS           bool       `json:"run_mrp_after_mps,omitempty"`
}

type MPSRunResult struct {
	RunID            uuid.UUID              `json:"run_id"`
	Status           string                 `json:"status"`
	Progress         []MPSProgressStep      `json:"progress"`
	PlannedOrders    []MPSPlannedOrder      `json:"planned_orders"`
	DependentDemands []MPSDependentDemand   `json:"dependent_demands"`
	Exceptions       []MPSExceptionMessage  `json:"exceptions"`
	MRPResult        *MRPRunResult          `json:"mrp_result,omitempty"`
	Summary          map[string]interface{} `json:"summary"`
}

type MPSProgressStep struct {
	Percent int    `json:"percent"`
	Message string `json:"message"`
}

type MPSPlannedOrder struct {
	ID                         uuid.UUID  `json:"id"`
	SiteID                     *uuid.UUID `json:"site_id,omitempty"`
	SiteCode                   string     `json:"site_code,omitempty"`
	SiteName                   string     `json:"site_name,omitempty"`
	ProductID                  uuid.UUID  `json:"product_id"`
	ProductSKU                 string     `json:"product_sku"`
	ProductName                string     `json:"product_name"`
	PlannedQty                 float64    `json:"planned_qty"`
	DueDate                    string     `json:"due_date"`
	IsFirmed                   bool       `json:"is_firmed"`
	ConvertedProductionOrderID *uuid.UUID `json:"converted_production_order_id,omitempty"`
	ConvertedOrderNumber       string     `json:"converted_order_number,omitempty"`
	ExceptionCode              string     `json:"exception_code,omitempty"`
	ExceptionMessage           string     `json:"exception_message,omitempty"`
}

type MPSDependentDemand struct {
	ID               uuid.UUID `json:"id"`
	ParentProductID  uuid.UUID `json:"parent_product_id"`
	ParentSKU        string    `json:"parent_sku"`
	ComponentID      uuid.UUID `json:"component_id"`
	ComponentSKU     string    `json:"component_sku"`
	ComponentName    string    `json:"component_name"`
	ComponentMRPType string    `json:"component_mrp_type"`
	DemandQty        float64   `json:"demand_qty"`
	RequirementDate  string    `json:"requirement_date"`
	Action           string    `json:"action"`
}

type MPSExceptionMessage struct {
	ID         uuid.UUID `json:"id"`
	ProductID  uuid.UUID `json:"product_id,omitempty"`
	ProductSKU string    `json:"product_sku,omitempty"`
	Code       string    `json:"code"`
	Severity   string    `json:"severity"`
	Message    string    `json:"message"`
}

type MRPRunResult struct {
	RunID                       uuid.UUID               `json:"run_id"`
	MPSRunID                    uuid.UUID               `json:"mps_run_id"`
	PlannedPurchaseRequisitions []MRPPlannedPurchaseReq `json:"planned_purchase_requisitions"`
	Exceptions                  []MRPExceptionMessage   `json:"exceptions"`
	Summary                     map[string]interface{}  `json:"summary"`
}

type MRPPlannedPurchaseReq struct {
	ID           uuid.UUID  `json:"id"`
	ProductID    uuid.UUID  `json:"product_id"`
	ProductSKU   string     `json:"product_sku"`
	ProductName  string     `json:"product_name"`
	SiteID       *uuid.UUID `json:"site_id,omitempty"`
	SiteCode     string     `json:"site_code,omitempty"`
	SiteName     string     `json:"site_name,omitempty"`
	VendorID     uuid.UUID  `json:"vendor_id"`
	VendorCode   string     `json:"vendor_code,omitempty"`
	VendorName   string     `json:"vendor_name,omitempty"`
	InfoRecordID uuid.UUID  `json:"info_record_id"`
	InfoRecord   string     `json:"info_record,omitempty"`
	DemandQty    float64    `json:"demand_qty"`
	NetQty       float64    `json:"net_qty"`
	OrderQty     float64    `json:"order_qty"`
	DueDate      string     `json:"due_date"`
	ReleaseDate  string     `json:"release_date"`
	PurchaseUOM  string     `json:"purchase_uom"`
	Currency     string     `json:"currency"`
	Price        float64    `json:"price"`
	Status       string     `json:"status"`
}

type MRPExceptionMessage struct {
	ID         uuid.UUID `json:"id"`
	ProductID  uuid.UUID `json:"product_id,omitempty"`
	ProductSKU string    `json:"product_sku,omitempty"`
	Code       string    `json:"code"`
	Severity   string    `json:"severity"`
	Message    string    `json:"message"`
}

type MRPPlanningParameters struct {
	CreatePurchaseReq int    `json:"create_purchase_req"`
	Scheduling        int    `json:"scheduling"`
	CreateDepReq      int    `json:"create_dep_req"`
	Description       string `json:"description"`
}

type MaterialRequirementsList struct {
	ProductID    uuid.UUID                     `json:"product_id"`
	ProductSKU   string                        `json:"product_sku"`
	ProductName  string                        `json:"product_name"`
	MaterialType string                        `json:"material_type,omitempty"`
	MRPType      string                        `json:"mrp_type,omitempty"`
	BaseUOM      string                        `json:"base_uom,omitempty"`
	SiteID       *uuid.UUID                    `json:"site_id,omitempty"`
	SiteCode     string                        `json:"site_code,omitempty"`
	SiteName     string                        `json:"site_name,omitempty"`
	StockQty     float64                       `json:"stock_qty"`
	AvailableQty float64                       `json:"available_qty"`
	SafetyStock  float64                       `json:"safety_stock"`
	AsOf         time.Time                     `json:"as_of"`
	Elements     []MaterialRequirementsElement `json:"elements"`
}

type MaterialRequirementsElement struct {
	Date           string  `json:"date"`
	MRPElement     string  `json:"mrp_element"`
	ElementData    string  `json:"element_data"`
	ReceiptQty     float64 `json:"receipt_qty,omitempty"`
	RequirementQty float64 `json:"requirement_qty,omitempty"`
	AvailableQty   float64 `json:"available_qty"`
	SourceType     string  `json:"source_type"`
	SourceID       string  `json:"source_id,omitempty"`
	Status         string  `json:"status,omitempty"`
	Exception      string  `json:"exception,omitempty"`
}

// ---------------------------------------------------------------
// Work Center
// ---------------------------------------------------------------

type WorkCenter struct {
	ID                uuid.UUID `json:"id"`
	TenantID          uuid.UUID `json:"tenant_id"`
	Code              string    `json:"code"`
	Name              string    `json:"name"`
	Description       string    `json:"description,omitempty"`
	WorkCenterType    string    `json:"work_center_type"`
	AvailableCapacity float64   `json:"available_capacity"`
	EfficiencyRate    float64   `json:"efficiency_rate"`
	CostPerHour       float64   `json:"cost_per_hour"`
	PlantLocation     string    `json:"plant_location,omitempty"`
	IsActive          bool      `json:"is_active"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

type CreateWorkCenterRequest struct {
	Code              string  `json:"code" binding:"required"`
	Name              string  `json:"name" binding:"required"`
	Description       string  `json:"description,omitempty"`
	WorkCenterType    string  `json:"work_center_type,omitempty"`
	AvailableCapacity float64 `json:"available_capacity,omitempty"`
	EfficiencyRate    float64 `json:"efficiency_rate,omitempty"`
	CostPerHour       float64 `json:"cost_per_hour,omitempty"`
	PlantLocation     string  `json:"plant_location,omitempty"`
}

type UpdateWorkCenterRequest struct {
	Code              *string  `json:"code,omitempty"`
	Name              *string  `json:"name,omitempty"`
	Description       *string  `json:"description,omitempty"`
	WorkCenterType    *string  `json:"work_center_type,omitempty"`
	AvailableCapacity *float64 `json:"available_capacity,omitempty"`
	EfficiencyRate    *float64 `json:"efficiency_rate,omitempty"`
	CostPerHour       *float64 `json:"cost_per_hour,omitempty"`
	PlantLocation     *string  `json:"plant_location,omitempty"`
	IsActive          *bool    `json:"is_active,omitempty"`
}

// ---------------------------------------------------------------
// Routing Template
// ---------------------------------------------------------------

type RoutingTemplate struct {
	ID            uuid.UUID           `json:"id"`
	TenantID      uuid.UUID           `json:"tenant_id"`
	TemplateCode  string              `json:"template_code"`
	TemplateName  string              `json:"template_name"`
	Description   string              `json:"description,omitempty"`
	Version       string              `json:"version"`
	Status        string              `json:"status"`
	TotalSetupMin float64             `json:"total_setup_min"`
	TotalRunMin   float64             `json:"total_run_min"`
	IsActive      bool                `json:"is_active"`
	CreatedAt     time.Time           `json:"created_at"`
	UpdatedAt     time.Time           `json:"updated_at"`
	Operations    []TemplateOperation `json:"operations,omitempty"`
}

type CreateRoutingTemplateRequest struct {
	TemplateCode string `json:"template_code" binding:"required"`
	TemplateName string `json:"template_name" binding:"required"`
	Description  string `json:"description,omitempty"`
	Version      string `json:"version,omitempty"`
}

type UpdateRoutingTemplateRequest struct {
	TemplateCode *string `json:"template_code,omitempty"`
	TemplateName *string `json:"template_name,omitempty"`
	Description  *string `json:"description,omitempty"`
	Version      *string `json:"version,omitempty"`
	Status       *string `json:"status,omitempty"`
	IsActive     *bool   `json:"is_active,omitempty"`

	// For inline operations sync
	Operations []CreateTemplateOperationRequest `json:"operations,omitempty"`
}

// ---------------------------------------------------------------
// Template Operation
// ---------------------------------------------------------------

type TemplateOperation struct {
	ID             uuid.UUID `json:"id"`
	TenantID       uuid.UUID `json:"tenant_id"`
	TemplateID     uuid.UUID `json:"template_id"`
	OperationNo    int       `json:"operation_no"`
	OperationName  string    `json:"operation_name"`
	Description    string    `json:"description,omitempty"`
	WorkCenterID   uuid.UUID `json:"work_center_id"`
	WorkCenterName string    `json:"work_center_name,omitempty"`
	WorkCenterCode string    `json:"work_center_code,omitempty"`
	SetupTimeMin   float64   `json:"setup_time_min"`
	RunTimeMin     float64   `json:"run_time_min"`
	IsActive       bool      `json:"is_active"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type CreateTemplateOperationRequest struct {
	ID            uuid.UUID `json:"id,omitempty"`
	TemplateID    uuid.UUID `json:"template_id,omitempty"`
	OperationNo   int       `json:"operation_no,omitempty"`
	OperationName string    `json:"operation_name" binding:"required"`
	Description   string    `json:"description,omitempty"`
	WorkCenterID  uuid.UUID `json:"work_center_id" binding:"required"`
	SetupTimeMin  float64   `json:"setup_time_min,omitempty"`
	RunTimeMin    float64   `json:"run_time_min,omitempty"`
}

type UpdateTemplateOperationRequest struct {
	OperationNo   *int       `json:"operation_no,omitempty"`
	OperationName *string    `json:"operation_name,omitempty"`
	Description   *string    `json:"description,omitempty"`
	WorkCenterID  *uuid.UUID `json:"work_center_id,omitempty"`
	SetupTimeMin  *float64   `json:"setup_time_min,omitempty"`
	RunTimeMin    *float64   `json:"run_time_min,omitempty"`
	IsActive      *bool      `json:"is_active,omitempty"`
}

// ---------------------------------------------------------------
// Production Order
// ---------------------------------------------------------------

type ProductionOrder struct {
	ID                uuid.UUID                 `json:"id"`
	TenantID          uuid.UUID                 `json:"tenant_id"`
	OrderNumber       string                    `json:"order_number"`
	SiteID            *uuid.UUID                `json:"site_id,omitempty"`
	SiteCode          string                    `json:"site_code,omitempty"`
	SiteName          string                    `json:"site_name,omitempty"`
	MaterialID        uuid.UUID                 `json:"material_id"`
	MaterialName      string                    `json:"material_name,omitempty"`
	MaterialSKU       string                    `json:"material_sku,omitempty"`
	OrderQty          float64                   `json:"order_qty"`
	CompletedQty      float64                   `json:"completed_qty"`
	BOMID             *uuid.UUID                `json:"bom_id,omitempty"`
	BOMVersion        string                    `json:"bom_version,omitempty"`
	Status            string                    `json:"status"`
	Priority          string                    `json:"priority"`
	SalesOrderID      *uuid.UUID                `json:"sales_order_id,omitempty"`
	SalesOrderNumber  string                    `json:"sales_order_number,omitempty"`
	SOItemID          *uuid.UUID                `json:"so_item_id,omitempty"`
	SOItemLineNo      *int                      `json:"so_item_line_no,omitempty"`
	SOItemProductName string                    `json:"so_item_product_name,omitempty"`
	PlannedStartDate  *time.Time                `json:"planned_start_date,omitempty"`
	PlannedEndDate    *time.Time                `json:"planned_end_date,omitempty"`
	ActualStartDate   *time.Time                `json:"actual_start_date,omitempty"`
	ActualEndDate     *time.Time                `json:"actual_end_date,omitempty"`
	Notes             string                    `json:"notes,omitempty"`
	CreatedBy         *uuid.UUID                `json:"created_by,omitempty"`
	UpdatedBy         *uuid.UUID                `json:"updated_by,omitempty"`
	CreatedAt         time.Time                 `json:"created_at"`
	UpdatedAt         time.Time                 `json:"updated_at"`
	Materials         []ProductionOrderMaterial `json:"materials,omitempty"`
}

type CreateProductionOrderRequest struct {
	MaterialID       uuid.UUID  `json:"material_id" binding:"required"`
	SiteID           *uuid.UUID `json:"site_id,omitempty"`
	OrderQty         float64    `json:"order_qty" binding:"required,min=0.0001"`
	BOMID            *uuid.UUID `json:"bom_id,omitempty"`
	Priority         string     `json:"priority,omitempty"`
	SalesOrderID     *uuid.UUID `json:"sales_order_id,omitempty"`
	SOItemID         *uuid.UUID `json:"so_item_id,omitempty"`
	PlannedStartDate string     `json:"planned_start_date,omitempty"`
	PlannedEndDate   string     `json:"planned_end_date,omitempty"`
	Notes            string     `json:"notes,omitempty"`
}

type UpdateProductionOrderRequest struct {
	OrderQty         *float64   `json:"order_qty,omitempty"`
	SiteID           *uuid.UUID `json:"site_id,omitempty"`
	BOMID            *uuid.UUID `json:"bom_id,omitempty"`
	Status           *string    `json:"status,omitempty"`
	Priority         *string    `json:"priority,omitempty"`
	SalesOrderID     *uuid.UUID `json:"sales_order_id,omitempty"`
	SOItemID         *uuid.UUID `json:"so_item_id,omitempty"`
	PlannedStartDate *string    `json:"planned_start_date,omitempty"`
	PlannedEndDate   *string    `json:"planned_end_date,omitempty"`
	ActualStartDate  *string    `json:"actual_start_date,omitempty"`
	ActualEndDate    *string    `json:"actual_end_date,omitempty"`
	Notes            *string    `json:"notes,omitempty"`
}

// ---------------------------------------------------------------
// Production Order Materials
// ---------------------------------------------------------------

type ProductionOrderMaterial struct {
	ID                uuid.UUID  `json:"id"`
	ProductionOrderID uuid.UUID  `json:"production_order_id"`
	ComponentID       uuid.UUID  `json:"component_id"`
	ComponentName     string     `json:"component_name,omitempty"`
	ComponentSKU      string     `json:"component_sku,omitempty"`
	BOMItemID         *uuid.UUID `json:"bom_item_id,omitempty"`
	RequiredQty       float64    `json:"required_qty"`
	IssueQty          float64    `json:"issue_qty"`
	UnitOfMeasure     string     `json:"unit_of_measure"`
	ItemPosition      int        `json:"item_position"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
}

type UpdatePOMaterialIssueRequest struct {
	IssueQty float64 `json:"issue_qty" binding:"required,min=0"`
}

// ---------------------------------------------------------------
// Production Order Time Confirmation
// ---------------------------------------------------------------

type ProductionOrderTimeConfirmation struct {
	ID                uuid.UUID  `json:"id"`
	TenantID          uuid.UUID  `json:"tenant_id"`
	ProductionOrderID uuid.UUID  `json:"production_order_id"`
	OrderNumber       string     `json:"order_number,omitempty"`
	MaterialSKU       string     `json:"material_sku,omitempty"`
	MaterialName      string     `json:"material_name,omitempty"`
	OperationID       *uuid.UUID `json:"operation_id,omitempty"`
	OperationNo       int        `json:"operation_no,omitempty"`
	OperationName     string     `json:"operation_name,omitempty"`
	WorkCenterID      *uuid.UUID `json:"work_center_id,omitempty"`
	WorkCenterCode    string     `json:"work_center_code,omitempty"`
	WorkCenterName    string     `json:"work_center_name,omitempty"`
	YieldQty          float64    `json:"yield_qty"`
	ScrapQty          float64    `json:"scrap_qty"`
	ReworkQty         float64    `json:"rework_qty"`
	SetupHours        float64    `json:"setup_hours"`
	LaborHours        float64    `json:"labor_hours"`
	MachineHours      float64    `json:"machine_hours"`
	ActualWorkHours   float64    `json:"actual_work_hours"`
	ConfirmationDate  time.Time  `json:"confirmation_date"`
	Notes             string     `json:"notes,omitempty"`
	ConfirmedBy       *uuid.UUID `json:"confirmed_by,omitempty"`
	CreatedAt         time.Time  `json:"created_at"`
}

type CreateTimeConfirmationRequest struct {
	OperationID      *uuid.UUID `json:"operation_id,omitempty"`
	YieldQty         float64    `json:"yield_qty" binding:"required,gt=0"`
	ScrapQty         float64    `json:"scrap_qty" binding:"gte=0"`
	ReworkQty        float64    `json:"rework_qty" binding:"gte=0"`
	SetupHours       float64    `json:"setup_hours" binding:"gte=0"`
	LaborHours       float64    `json:"labor_hours" binding:"gte=0"`
	MachineHours     float64    `json:"machine_hours" binding:"gte=0"`
	ActualWorkHours  float64    `json:"actual_work_hours" binding:"gte=0"`
	ConfirmationDate string     `json:"confirmation_date,omitempty"`
	Notes            string     `json:"notes,omitempty"`
}
