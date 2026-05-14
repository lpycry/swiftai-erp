package handler

import (
	"fmt"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"

	"github.com/swiftai-erp/backend/pkg/response"
)

type PeriodHandler struct {
	db *pgxpool.Pool
}

func NewPeriodHandler(db *pgxpool.Pool) *PeriodHandler {
	return &PeriodHandler{db: db}
}

// ListPeriods handles GET /api/v1/periods?org_id=xxx&year=2026
func (h *PeriodHandler) ListPeriods(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	orgIDStr := c.Query("org_id")
	yearStr := c.DefaultQuery("year", fmt.Sprintf("%d", time.Now().Year()))
	year, _ := strconv.Atoi(yearStr)

	query := `SELECT id, tenant_id, organization_id, fiscal_year, period_no, start_date, end_date, is_open, is_locked, created_at, updated_at
		FROM gl_periods WHERE tenant_id = $1 AND fiscal_year = $2`
	args := []interface{}{tenantID, year}
	argIdx := 3

	if orgIDStr != "" {
		orgID, err := uuid.Parse(orgIDStr)
		if err != nil {
			response.BadRequest(c, "invalid org_id")
			return
		}
		query += fmt.Sprintf(" AND (organization_id = $%d OR organization_id IS NULL)", argIdx)
		args = append(args, orgID)
		argIdx++
	}
	query += " ORDER BY period_no"

	rows, err := h.db.Query(c.Request.Context(), query, args...)
	if err != nil {
		log.Err(err).Msg("list periods failed")
		response.InternalError(c, "failed to list periods")
		return
	}
	defer rows.Close()

	type Period struct {
		ID             uuid.UUID  `json:"id"`
		TenantID       uuid.UUID  `json:"tenant_id"`
		OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
		FiscalYear     int        `json:"fiscal_year"`
		PeriodNo       int        `json:"period_no"`
		StartDate      string     `json:"start_date"`
		EndDate        string     `json:"end_date"`
		IsOpen         bool       `json:"is_open"`
		IsLocked       bool       `json:"is_locked"`
		CreatedAt      time.Time  `json:"created_at"`
		UpdatedAt      time.Time  `json:"updated_at"`
	}

	var periods []Period
	for rows.Next() {
		var p Period
		var sd, ed time.Time
		err := rows.Scan(&p.ID, &p.TenantID, &p.OrganizationID, &p.FiscalYear, &p.PeriodNo,
			&sd, &ed, &p.IsOpen, &p.IsLocked, &p.CreatedAt, &p.UpdatedAt)
		if err != nil {
			log.Err(err).Msg("scan period failed")
			continue
		}
		p.StartDate = sd.Format("2006-01-02")
		p.EndDate = ed.Format("2006-01-02")
		periods = append(periods, p)
	}

	response.OK(c, periods)
}

// UpdatePeriod handles PUT /api/v1/periods/:id
func (h *PeriodHandler) UpdatePeriod(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	periodID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "invalid period id")
		return
	}

	var req struct {
		IsOpen   *bool `json:"is_open,omitempty"`
		IsLocked *bool `json:"is_locked,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if req.IsOpen == nil && req.IsLocked == nil {
		response.BadRequest(c, "nothing to update")
		return
	}

	setClauses := ""
	args := []interface{}{}
	argIdx := 1

	if req.IsOpen != nil {
		setClauses += fmt.Sprintf("is_open = $%d, ", argIdx)
		args = append(args, *req.IsOpen)
		argIdx++
	}
	if req.IsLocked != nil {
		setClauses += fmt.Sprintf("is_locked = $%d, ", argIdx)
		args = append(args, *req.IsLocked)
		argIdx++
	}

	args = append(args, periodID, tenantID)
	query := fmt.Sprintf(`UPDATE gl_periods SET %s updated_at = NOW() WHERE id = $%d AND tenant_id = $%d`,
		setClauses, argIdx, argIdx+1)

	_, err = h.db.Exec(c.Request.Context(), query, args...)
	if err != nil {
		log.Err(err).Msg("update period failed")
		response.InternalError(c, "failed to update period")
		return
	}

	response.OK(c, gin.H{"message": "period updated"})
}

// GeneratePeriods handles POST /api/v1/periods/generate
func (h *PeriodHandler) GeneratePeriods(c *gin.Context) {
	tenantID, err := getTenantID(c)
	if err != nil {
		response.BadRequest(c, "missing tenant context")
		return
	}

	var req struct {
		Year           int        `json:"year" binding:"required"`
		OrganizationID *uuid.UUID `json:"organization_id,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "invalid request")
		return
	}

	if req.Year < 2020 || req.Year > 2040 {
		response.BadRequest(c, "year must be between 2020 and 2040")
		return
	}

	created := 0
	for month := 1; month <= 12; month++ {
		startDate := time.Date(req.Year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
		endDate := startDate.AddDate(0, 1, -1)

		_, err := h.db.Exec(c.Request.Context(), `
			INSERT INTO gl_periods (tenant_id, organization_id, fiscal_year, period_no, start_date, end_date, is_open, is_locked)
			VALUES ($1, $2, $3, $4, $5, $6, true, false)
			ON CONFLICT (tenant_id, fiscal_year, period_no) DO NOTHING`,
			tenantID, req.OrganizationID, req.Year, month, startDate, endDate)
		if err != nil {
			log.Warn().Err(err).Int("period", month).Msg("skip existing period")
			continue
		}
		created++
	}

	response.Created(c, gin.H{"message": fmt.Sprintf("%d periods generated", created), "count": created})
}


