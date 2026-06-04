package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/rs/zerolog/log"
)

// ── Request / Response Models ──

type TaxCalculationRequest struct {
	CustomerID string  `json:"customer_id" binding:"required"`
	NetAmount  float64 `json:"net_amount"`
}

type TaxCalculationResult struct {
	TaxRate   float64 `json:"tax_rate"`
	TaxAmount float64 `json:"tax_amount"`
	Source    string  `json:"source"`
	Detail    string  `json:"detail"`
}

// ── Business Logic ──

func (s *SalesService) CalculateTax(ctx context.Context, customerID uuid.UUID, netAmount float64) (*TaxCalculationResult, error) {
	pool := s.repo.Pool()

	// 1. Get customer — check tax exempt status
	cust, err := s.getCustomerForTax(ctx, pool, customerID)
	if err != nil {
		return nil, fmt.Errorf("get customer for tax: %w", err)
	}

	now := time.Now()
	if cust.IsTaxExempt {
		if cust.TaxExemptStartDate != nil && cust.TaxExemptEndDate != nil {
			if !now.Before(*cust.TaxExemptStartDate) && !now.After(*cust.TaxExemptEndDate) {
				return &TaxCalculationResult{
					TaxRate: 0, TaxAmount: 0,
					Source: "EXEMPT",
					Detail: fmt.Sprintf("Customer %s is tax exempt (%s – %s)",
						cust.Name,
						cust.TaxExemptStartDate.Format("2006-01-02"),
						cust.TaxExemptEndDate.Format("2006-01-02"),
					),
				}, nil
			}
		}
	}

	// 2. If customer has a default tax jurisdiction, use its tax_rate
	if cust.DefaultTaxJurisdictionID != nil {
		taxRate, err := s.getJurisdictionRate(ctx, pool, *cust.DefaultTaxJurisdictionID)
		if err == nil {
			return &TaxCalculationResult{
				TaxRate:   taxRate,
				TaxAmount: taxRate * netAmount,
				Source:    "JURISDICTION",
				Detail:    fmt.Sprintf("Default tax jurisdiction rate: %.4f%%", taxRate*100),
			}, nil
		}
		log.Warn().Err(err).Msg("default tax jurisdiction lookup failed, falling back")
	}

	// 3. Try tax_jurisdiction_rules by product's tax_category
	shippingZip := cust.ShippingZip
	shippingState := cust.ShippingState

	// Try rules by zip first, then state
	if shippingZip != "" {
		ruleResult, err := s.getRuleRateByZipOrState(ctx, pool, shippingZip, "")
		if err == nil {
			ruleResult.TaxAmount = ruleResult.TaxRate * netAmount
			return ruleResult, nil
		}
	}

	if shippingState != "" {
		ruleResult, err := s.getRuleRateByZipOrState(ctx, pool, "", shippingState)
		if err == nil {
			ruleResult.TaxAmount = ruleResult.TaxRate * netAmount
			return ruleResult, nil
		}
	}

	// 4. Fall back to tax_jurisdictions by zip then state
	if shippingZip != "" {
		taxRate, err := s.getJurisdictionRateByZip(ctx, pool, shippingZip)
		if err == nil {
			return &TaxCalculationResult{
				TaxRate:   taxRate,
				TaxAmount: taxRate * netAmount,
				Source:    "JURIS_ZIP",
				Detail:    fmt.Sprintf("Jurisdiction by zip %s rate: %.4f%%", shippingZip, taxRate*100),
			}, nil
		}
	}

	if shippingState != "" {
		taxRate, err := s.getJurisdictionRateByState(ctx, pool, shippingState)
		if err == nil {
			return &TaxCalculationResult{
				TaxRate:   taxRate,
				TaxAmount: taxRate * netAmount,
				Source:    "JURIS_STATE",
				Detail:    fmt.Sprintf("Jurisdiction by state %s rate: %.4f%%", shippingState, taxRate*100),
			}, nil
		}
	}

	// 5. No match — return 0
	return &TaxCalculationResult{
		TaxRate: 0, TaxAmount: 0,
		Source: "NONE",
		Detail: "No tax jurisdiction or rule matched for customer's shipping address",
	}, nil
}

// ── Internal helpers ──

type customerTaxInfo struct {
	Name                     string
	IsTaxExempt              bool
	TaxExemptStartDate       *time.Time
	TaxExemptEndDate         *time.Time
	DefaultTaxJurisdictionID *uuid.UUID
	ShippingZip              string
	ShippingState            string
}

func (s *SalesService) getCustomerForTax(ctx context.Context, pool interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}, customerID uuid.UUID) (*customerTaxInfo, error) {
	c := &customerTaxInfo{}
	err := pool.QueryRow(ctx, `
		SELECT name, is_tax_exempt, tax_exempt_start_date, tax_exempt_end_date,
		       default_tax_jurisdiction_id,
		       COALESCE(shipping_zip,''), COALESCE(shipping_state,'')
		FROM customers WHERE id = $1
	`, customerID).Scan(
		&c.Name, &c.IsTaxExempt, &c.TaxExemptStartDate, &c.TaxExemptEndDate,
		&c.DefaultTaxJurisdictionID,
		&c.ShippingZip, &c.ShippingState,
	)
	if err != nil {
		return nil, err
	}
	return c, nil
}

func (s *SalesService) getJurisdictionRate(ctx context.Context, pool interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}, jurisdictionID uuid.UUID) (float64, error) {
	var rate float64
	err := pool.QueryRow(ctx,
		`SELECT tax_rate FROM tax_jurisdictions WHERE id = $1`,
		jurisdictionID,
	).Scan(&rate)
	return rate, err
}

func (s *SalesService) getJurisdictionRateByZip(ctx context.Context, pool interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}, zipCode string) (float64, error) {
	var rate float64
	err := pool.QueryRow(ctx,
		`SELECT tax_rate FROM tax_jurisdictions WHERE zip_code = $1 LIMIT 1`,
		zipCode,
	).Scan(&rate)
	return rate, err
}

func (s *SalesService) getJurisdictionRateByState(ctx context.Context, pool interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}, stateCode string) (float64, error) {
	var rate float64
	err := pool.QueryRow(ctx,
		`SELECT tax_rate FROM tax_jurisdictions WHERE state = $1 LIMIT 1`,
		stateCode,
	).Scan(&rate)
	return rate, err
}

func (s *SalesService) getRuleRateByZipOrState(ctx context.Context, pool interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}, zipCode, stateCode string) (*TaxCalculationResult, error) {
	var ruleBaseRate float64
	var ruleTaxCategoryCode string

	if zipCode != "" {
		err := pool.QueryRow(ctx, `
			SELECT jr.base_rate, jr.tax_category_code
			FROM tax_jurisdiction_rules jr
			JOIN tax_jurisdictions tj ON tj.id = jr.jurisdiction_id
			WHERE jr.zip_code = $1
			LIMIT 1
		`, zipCode).Scan(&ruleBaseRate, &ruleTaxCategoryCode)
		if err == nil {
			return &TaxCalculationResult{
				TaxRate: ruleBaseRate,
				Source:  "RULE_ZIP",
				Detail:  fmt.Sprintf("Tax rule (zip %s, category %s) rate: %.4f%%", zipCode, ruleTaxCategoryCode, ruleBaseRate*100),
			}, nil
		}
	}

	if stateCode != "" {
		err := pool.QueryRow(ctx, `
			SELECT jr.base_rate, jr.tax_category_code
			FROM tax_jurisdiction_rules jr
			JOIN tax_jurisdictions tj ON tj.id = jr.jurisdiction_id
			WHERE jr.state_code = $1
			LIMIT 1
		`, stateCode).Scan(&ruleBaseRate, &ruleTaxCategoryCode)
		if err == nil {
			return &TaxCalculationResult{
				TaxRate: ruleBaseRate,
				Source:  "RULE_STATE",
				Detail:  fmt.Sprintf("Tax rule (state %s, category %s) rate: %.4f%%", stateCode, ruleTaxCategoryCode, ruleBaseRate*100),
			}, nil
		}
	}

	return nil, fmt.Errorf("no tax rule found for zip=%q state=%q", zipCode, stateCode)
}
