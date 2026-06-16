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
	BOMID        uuid.UUID  `json:"bom_id"`
	TenantID     uuid.UUID  `json:"tenant_id"`
	MaterialID   uuid.UUID  `json:"material_id"`
	MaterialName string     `json:"material_name,omitempty"`
	MaterialSKU  string     `json:"material_sku,omitempty"`
	BOMVersion   string     `json:"bom_version"`
	BOMUsage     string     `json:"bom_usage"`
	Status       string     `json:"status"`
	BaseQty      float64    `json:"base_qty"`
	ValidFrom    time.Time  `json:"valid_from"`
	ValidTo      time.Time  `json:"valid_to"`
	Description  string     `json:"description,omitempty"`
	IsActive     bool       `json:"is_active"`
	CreatedBy    *uuid.UUID `json:"created_by,omitempty"`
	UpdatedBy    *uuid.UUID `json:"updated_by,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
	Items        []BOMItem  `json:"items,omitempty"`
}

type CreateBOMRequest struct {
	MaterialID  uuid.UUID              `json:"material_id" binding:"required"`
	BOMVersion  string                 `json:"bom_version" binding:"required"`
	BOMUsage    string                 `json:"bom_usage,omitempty"`
	BaseQty     float64                `json:"base_qty,omitempty"`
	ValidFrom   string                 `json:"valid_from,omitempty"`
	ValidTo     string                 `json:"valid_to,omitempty"`
	Description string                 `json:"description,omitempty"`
	IsActive    bool                   `json:"is_active"`
	Items       []CreateBOMItemRequest `json:"items" binding:"required,min=1,dive"`
}

type UpdateBOMRequest struct {
	BOMVersion  *string  `json:"bom_version,omitempty"`
	BOMUsage    *string  `json:"bom_usage,omitempty"`
	BaseQty     *float64 `json:"base_qty,omitempty"`
	ValidFrom   *string  `json:"valid_from,omitempty"`
	ValidTo     *string  `json:"valid_to,omitempty"`
	Description *string  `json:"description,omitempty"`
	IsActive    *bool    `json:"is_active,omitempty"`

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
	TemplateID    uuid.UUID `json:"template_id" binding:"required"`
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
	ID               uuid.UUID  `json:"id"`
	TenantID         uuid.UUID  `json:"tenant_id"`
	OrderNumber      string     `json:"order_number"`
	MaterialID       uuid.UUID  `json:"material_id"`
	MaterialName     string     `json:"material_name,omitempty"`
	MaterialSKU      string     `json:"material_sku,omitempty"`
	OrderQty         float64    `json:"order_qty"`
	BOMID            *uuid.UUID `json:"bom_id,omitempty"`
	BOMVersion       string     `json:"bom_version,omitempty"`
	Status           string     `json:"status"`
	Priority         string     `json:"priority"`
	PlannedStartDate *time.Time `json:"planned_start_date,omitempty"`
	PlannedEndDate   *time.Time `json:"planned_end_date,omitempty"`
	ActualStartDate  *time.Time `json:"actual_start_date,omitempty"`
	ActualEndDate    *time.Time `json:"actual_end_date,omitempty"`
	Notes            string     `json:"notes,omitempty"`
	CreatedBy        *uuid.UUID `json:"created_by,omitempty"`
	UpdatedBy        *uuid.UUID `json:"updated_by,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

type CreateProductionOrderRequest struct {
	MaterialID       uuid.UUID  `json:"material_id" binding:"required"`
	OrderQty         float64    `json:"order_qty" binding:"required,min=0.0001"`
	BOMID            *uuid.UUID `json:"bom_id,omitempty"`
	Priority         string     `json:"priority,omitempty"`
	PlannedStartDate string     `json:"planned_start_date,omitempty"`
	PlannedEndDate   string     `json:"planned_end_date,omitempty"`
	Notes            string     `json:"notes,omitempty"`
}

type UpdateProductionOrderRequest struct {
	OrderQty         *float64   `json:"order_qty,omitempty"`
	BOMID            *uuid.UUID `json:"bom_id,omitempty"`
	Status           *string    `json:"status,omitempty"`
	Priority         *string    `json:"priority,omitempty"`
	PlannedStartDate *string    `json:"planned_start_date,omitempty"`
	PlannedEndDate   *string    `json:"planned_end_date,omitempty"`
	ActualStartDate  *string    `json:"actual_start_date,omitempty"`
	ActualEndDate    *string    `json:"actual_end_date,omitempty"`
	Notes            *string    `json:"notes,omitempty"`
}
