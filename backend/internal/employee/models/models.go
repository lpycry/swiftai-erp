package models

import (
	"time"

	"github.com/google/uuid"
)

type EmployeeBase struct {
	ID               uuid.UUID  `json:"id"`
	TenantID         uuid.UUID  `json:"tenant_id"`
	EmployeeCode     string     `json:"employee_code"`
	FirstName        string     `json:"first_name"`
	MiddleName       string     `json:"middle_name,omitempty"`
	LastName         string     `json:"last_name"`
	LegalName        string     `json:"legal_name,omitempty"`         // computed: First + Middle + Last
	TaxID            string     `json:"tax_id,omitempty"`
	DateOfBirth      string     `json:"date_of_birth,omitempty"`
	PositionID       *uuid.UUID `json:"position_id,omitempty"`
	DepartmentID     *uuid.UUID `json:"department_id,omitempty"`
	HireDate         string     `json:"hire_date,omitempty"`
	Email            string     `json:"email,omitempty"`
	Phone            string     `json:"phone,omitempty"`
	LegalAddress     string     `json:"legal_address,omitempty"`
	EmergencyContacts string    `json:"emergency_contacts,omitempty"` // JSON array
	WorkerType       string     `json:"worker_type,omitempty"`
	ManagerID        *uuid.UUID `json:"manager_id,omitempty"`
	IsActive         bool       `json:"is_active"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

func (e *EmployeeBase) FullName() string {
	if e.MiddleName != "" {
		return e.FirstName + " " + e.MiddleName + " " + e.LastName
	}
	return e.FirstName + " " + e.LastName
}

type CreateEmployeeRequest struct {
	EmployeeCode     string `json:"employee_code" binding:"required"`
	FirstName        string `json:"first_name" binding:"required"`
	MiddleName       string `json:"middle_name,omitempty"`
	LastName         string `json:"last_name" binding:"required"`
	TaxID            string `json:"tax_id,omitempty"`
	DateOfBirth      string `json:"date_of_birth,omitempty"`
	PositionID       string `json:"position_id,omitempty"`
	DepartmentID     string `json:"department_id,omitempty"`
	HireDate         string `json:"hire_date,omitempty"`
	Email            string `json:"email,omitempty"`
	Phone            string `json:"phone,omitempty"`
	LegalAddress     string `json:"legal_address,omitempty"`
	EmergencyContacts string `json:"emergency_contacts,omitempty"`
	WorkerType       string `json:"worker_type,omitempty"`
	ManagerID        string `json:"manager_id,omitempty"`
	IsActive         *bool  `json:"is_active,omitempty"`
}

type UpdateEmployeeRequest struct {
	FirstName        string `json:"first_name"`
	MiddleName       string `json:"middle_name,omitempty"`
	LastName         string `json:"last_name"`
	TaxID            string `json:"tax_id,omitempty"`
	DateOfBirth      string `json:"date_of_birth,omitempty"`
	PositionID       string `json:"position_id,omitempty"`
	DepartmentID     string `json:"department_id,omitempty"`
	HireDate         string `json:"hire_date,omitempty"`
	Email            string `json:"email,omitempty"`
	Phone            string `json:"phone,omitempty"`
	LegalAddress     string `json:"legal_address,omitempty"`
	EmergencyContacts string `json:"emergency_contacts,omitempty"`
	WorkerType       string `json:"worker_type,omitempty"`
	ManagerID        string `json:"manager_id,omitempty"`
	IsActive         *bool  `json:"is_active,omitempty"`
}

// ── Employee Data History (Infotype) ──

type EmployeeDataHistory struct {
	RecordID     uuid.UUID              `json:"record_id"`
	EmployeeID   uuid.UUID              `json:"employee_id"`
	InfotypeCode string                 `json:"infotype_code"`
	DataPayload  map[string]interface{} `json:"data_payload"`
	ValidFrom    string                 `json:"valid_from"`
	ValidTo      string                 `json:"valid_to"`
	CreatedAt    time.Time              `json:"created_at"`
	UpdatedAt    time.Time              `json:"updated_at"`
}

type CreateDataHistoryRequest struct {
	EmployeeID   string                 `json:"employee_id"` // optional, from URL
	InfotypeCode string                 `json:"infotype_code" binding:"required"`
	DataPayload  map[string]interface{} `json:"data_payload" binding:"required"`
	ValidFrom    string                 `json:"valid_from"`
	ValidTo      string                 `json:"valid_to"`
}

type UpdateDataHistoryRequest struct {
	DataPayload map[string]interface{} `json:"data_payload"`
	ValidFrom   string                 `json:"valid_from"`
	ValidTo     string                 `json:"valid_to"`
}

// ── Current view ──

type EmployeeCurrentView struct {
	EmployeeID   uuid.UUID `json:"employee_id"`
	EmployeeCode string    `json:"employee_code"`
	FirstName    string    `json:"first_name"`
	LastName     string    `json:"last_name"`
	FullName     string    `json:"full_name"`
	TaxID        string    `json:"tax_id,omitempty"`
	DateOfBirth  string    `json:"date_of_birth,omitempty"`
	IsActive     bool      `json:"is_active"`
	PositionID   string    `json:"position_id,omitempty"`
	JobTitle     string    `json:"job_title,omitempty"`
	PositionCode string    `json:"position_code,omitempty"`
	DeptID       string    `json:"dept_id,omitempty"`
	DeptName     string    `json:"dept_name,omitempty"`
	CostCenterID string    `json:"cost_center_id,omitempty"`
	SalaryAmount string    `json:"salary_amount,omitempty"`
	Email        string    `json:"email,omitempty"`
	Phone        string    `json:"phone,omitempty"`
	WorkerType   string    `json:"worker_type,omitempty"`
	HireDate     string    `json:"hire_date,omitempty"`
}

type EmployeeDetail struct {
	Base    *EmployeeBase           `json:"base"`
	History []*EmployeeDataHistory   `json:"history"`
}
