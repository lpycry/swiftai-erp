package handler

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	emodels "github.com/swiftai-erp/backend/internal/employee/models"
	"github.com/swiftai-erp/backend/internal/employee/repository"
	"github.com/swiftai-erp/backend/pkg/response"
)

type EmployeeHandler struct {
	repo *repository.EmployeeRepo
}

func NewEmployeeHandler(repo *repository.EmployeeRepo) *EmployeeHandler {
	return &EmployeeHandler{repo: repo}
}

func (h *EmployeeHandler) CreateEmployee(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }

	var req emodels.CreateEmployeeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}

	isActive := true
	if req.IsActive != nil { isActive = *req.IsActive }

	var posID, deptID, mgrID *uuid.UUID
	if req.PositionID != "" { if p, e := uuid.Parse(req.PositionID); e == nil { posID = &p } }
	if req.DepartmentID != "" { if p, e := uuid.Parse(req.DepartmentID); e == nil { deptID = &p } }
	if req.ManagerID != "" { if p, e := uuid.Parse(req.ManagerID); e == nil { mgrID = &p } }

	if req.WorkerType == "" { req.WorkerType = "Regular" }
	if req.EmergencyContacts == "" { req.EmergencyContacts = "[]" }

	now := time.Now()
	emp := &emodels.EmployeeBase{
		ID: uuid.New(), TenantID: tenantID,
		EmployeeCode: req.EmployeeCode,
		FirstName: req.FirstName, MiddleName: req.MiddleName, LastName: req.LastName,
		TaxID: req.TaxID, DateOfBirth: req.DateOfBirth,
		PositionID: posID, DepartmentID: deptID, HireDate: req.HireDate,
		Email: req.Email, Phone: req.Phone, LegalAddress: req.LegalAddress,
		EmergencyContacts: req.EmergencyContacts, WorkerType: req.WorkerType,
		ManagerID: mgrID,
		IsActive: isActive, CreatedAt: now, UpdatedAt: now,
	}
	if err := h.repo.CreateBase(c.Request.Context(), emp); err != nil {
		log.Err(err).Msg("create employee failed")
		response.InternalError(c, err.Error())
		return
	}
	response.Created(c, emp)
}

func (h *EmployeeHandler) ListEmployees(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	mode := c.DefaultQuery("mode", "list")
	search := c.Query("search")

	if mode == "current" {
		list, err := h.repo.ListCurrentView(c.Request.Context(), tenantID, search)
		if err != nil { response.InternalError(c, err.Error()); return }
		response.OK(c, list)
		return
	}
	list, err := h.repo.ListBase(c.Request.Context(), tenantID, search)
	if err != nil { response.InternalError(c, err.Error()); return }
	response.OK(c, list)
}

func (h *EmployeeHandler) GetEmployee(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid employee id"); return }

	base, err := h.repo.GetBaseByID(c.Request.Context(), id, tenantID)
	if err != nil { response.InternalError(c, err.Error()); return }
	if base == nil { response.NotFound(c, "employee not found"); return }

	if c.Query("include") == "all" {
		history, _ := h.repo.ListHistory(c.Request.Context(), id, "")
		response.OK(c, gin.H{"base": base, "history": history})
		return
	}
	response.OK(c, base)
}

func (h *EmployeeHandler) UpdateEmployee(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid employee id"); return }

	var req emodels.UpdateEmployeeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	emp, err := h.repo.UpdateBase(c.Request.Context(), id, tenantID, &req)
	if err != nil { response.InternalError(c, err.Error()); return }
	if emp == nil { response.NotFound(c, "employee not found"); return }
	response.OK(c, emp)
}

func (h *EmployeeHandler) DeleteEmployee(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil { response.BadRequest(c, "missing tenant context"); return }
	id, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid employee id"); return }
	if err := h.repo.DeleteBase(c.Request.Context(), id, tenantID); err != nil {
		response.InternalError(c, err.Error()); return
	}
	response.OK(c, gin.H{"message": "employee deleted"})
}

// ── Data History (Infotype) ──

func (h *EmployeeHandler) CreateDataHistory(c *gin.Context) {
	empID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid employee id"); return }
	var req emodels.CreateDataHistoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	validFrom := req.ValidFrom; if validFrom == "" { validFrom = time.Now().Format("2006-01-02") }
	validTo := req.ValidTo; if validTo == "" { validTo = "9999-12-31" }
	now := time.Now()
	rec := &emodels.EmployeeDataHistory{
		RecordID: uuid.New(), EmployeeID: empID,
		InfotypeCode: req.InfotypeCode, DataPayload: req.DataPayload,
		ValidFrom: validFrom, ValidTo: validTo, CreatedAt: now, UpdatedAt: now,
	}
	if err := h.repo.CreateHistory(c.Request.Context(), rec); err != nil {
		log.Err(err).Msg("create data history failed")
		response.InternalError(c, err.Error()); return
	}
	response.Created(c, rec)
}

func (h *EmployeeHandler) ListDataHistory(c *gin.Context) {
	empID, err := uuid.Parse(c.Param("id"))
	if err != nil { response.BadRequest(c, "invalid employee id"); return }
	list, err := h.repo.ListHistory(c.Request.Context(), empID, c.Query("infotype"))
	if err != nil { response.InternalError(c, err.Error()); return }
	response.OK(c, list)
}

func (h *EmployeeHandler) UpdateDataHistory(c *gin.Context) {
	recordID, err := uuid.Parse(c.Param("recordId"))
	if err != nil { response.BadRequest(c, "invalid record id"); return }
	var req emodels.UpdateDataHistoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request", response.ErrorDetail{Field: "body", Message: err.Error()})
		return
	}
	rec, err := h.repo.UpdateHistory(c.Request.Context(), recordID, &req)
	if err != nil { response.InternalError(c, err.Error()); return }
	if rec == nil { response.NotFound(c, "record not found"); return }
	response.OK(c, rec)
}

func (h *EmployeeHandler) DeleteDataHistory(c *gin.Context) {
	recordID, err := uuid.Parse(c.Param("recordId"))
	if err != nil { response.BadRequest(c, "invalid record id"); return }
	if err := h.repo.DeleteHistory(c.Request.Context(), recordID); err != nil {
		response.InternalError(c, err.Error()); return
	}
	response.OK(c, gin.H{"message": "record deleted"})
}

func getTenantID(c *gin.Context) (uuid.UUID, error) {
	tid := c.GetString("tenant_id")
	if tid == "" { return uuid.Nil, fmt.Errorf("missing tenant context") }
	return uuid.Parse(tid)
}
