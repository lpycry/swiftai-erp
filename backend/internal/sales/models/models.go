package models

import (
	"time"

	"github.com/google/uuid"
)

// ── Customer Master (SAP-style) ──

type Customer struct {
	ID                      uuid.UUID  `json:"id"`
	TenantID                uuid.UUID  `json:"tenant_id"`
	CustomerCode            string     `json:"customer_code"`
	Name                    string     `json:"name"`
	TaxNumber               string     `json:"tax_number,omitempty"`
	CustomerType            string     `json:"customer_type"`
	Currency                string     `json:"currency"`
	PaymentTerms            string     `json:"payment_terms"`
	ContactPerson           string     `json:"contact_person,omitempty"`
	ContactEmail            string     `json:"contact_email,omitempty"`
	ContactPhone            string     `json:"contact_phone,omitempty"`
	BillingStreet           string     `json:"billing_street,omitempty"`
	BillingCity             string     `json:"billing_city,omitempty"`
	BillingState            string     `json:"billing_state,omitempty"`
	BillingZip              string     `json:"billing_zip,omitempty"`
	BillingCountry          string     `json:"billing_country,omitempty"`
	ShippingStreet          string     `json:"shipping_street,omitempty"`
	ShippingCity            string     `json:"shipping_city,omitempty"`
	ShippingState           string     `json:"shipping_state,omitempty"`
	ShippingZip             string     `json:"shipping_zip,omitempty"`
	ShippingCountry         string     `json:"shipping_country,omitempty"`
	Status                  string     `json:"status"`
	IsTaxExempt             bool       `json:"is_tax_exempt"`
	TaxExemptionCert        string     `json:"tax_exemption_cert,omitempty"`
	TaxExemptStartDate      *time.Time `json:"tax_exempt_start_date,omitempty"`
	TaxExemptEndDate        *time.Time `json:"tax_exempt_end_date,omitempty"`
	TaxExemptReason         string     `json:"tax_exempt_reason,omitempty"`
	DefaultTaxJurisdictionID *uuid.UUID `json:"default_tax_jurisdiction_id,omitempty"`
	IsActive                bool       `json:"is_active"`
	CreatedAt               time.Time  `json:"created_at"`
	UpdatedAt               time.Time  `json:"updated_at"`
	Certificates            []CustomerCertificate `json:"certificates,omitempty"`
}

type CreateCustomerRequest struct {
	CustomerCode             string   `json:"customer_code" binding:"required"`
	Name                     string   `json:"name" binding:"required"`
	TaxNumber                string   `json:"tax_number,omitempty"`
	CustomerType             string   `json:"customer_type,omitempty"`
	Currency                 string   `json:"currency,omitempty"`
	PaymentTerms             string   `json:"payment_terms,omitempty"`
	ContactPerson            string   `json:"contact_person,omitempty"`
	ContactEmail             string   `json:"contact_email,omitempty"`
	ContactPhone             string   `json:"contact_phone,omitempty"`
	BillingStreet            string   `json:"billing_street,omitempty"`
	BillingCity              string   `json:"billing_city,omitempty"`
	BillingState             string   `json:"billing_state,omitempty"`
	BillingZip               string   `json:"billing_zip,omitempty"`
	BillingCountry           string   `json:"billing_country,omitempty"`
	ShippingStreet           string   `json:"shipping_street,omitempty"`
	ShippingCity             string   `json:"shipping_city,omitempty"`
	ShippingState            string   `json:"shipping_state,omitempty"`
	ShippingZip              string   `json:"shipping_zip,omitempty"`
	ShippingCountry          string   `json:"shipping_country,omitempty"`
	IsTaxExempt              *bool    `json:"is_tax_exempt,omitempty"`
	TaxExemptionCert         string   `json:"tax_exemption_cert,omitempty"`
	TaxExemptStartDate       string   `json:"tax_exempt_start_date,omitempty"`
	TaxExemptEndDate         string   `json:"tax_exempt_end_date,omitempty"`
	TaxExemptReason          string   `json:"tax_exempt_reason,omitempty"`
	DefaultTaxJurisdictionID *string  `json:"default_tax_jurisdiction_id,omitempty"`
}

type UpdateCustomerRequest struct {
	Name                     *string   `json:"name,omitempty"`
	TaxNumber                *string   `json:"tax_number,omitempty"`
	CustomerType             *string   `json:"customer_type,omitempty"`
	Currency                 *string   `json:"currency,omitempty"`
	PaymentTerms             *string   `json:"payment_terms,omitempty"`
	ContactPerson            *string   `json:"contact_person,omitempty"`
	ContactEmail             *string   `json:"contact_email,omitempty"`
	ContactPhone             *string   `json:"contact_phone,omitempty"`
	BillingStreet            *string   `json:"billing_street,omitempty"`
	BillingCity              *string   `json:"billing_city,omitempty"`
	BillingState             *string   `json:"billing_state,omitempty"`
	BillingZip               *string   `json:"billing_zip,omitempty"`
	BillingCountry           *string   `json:"billing_country,omitempty"`
	ShippingStreet           *string   `json:"shipping_street,omitempty"`
	ShippingCity             *string   `json:"shipping_city,omitempty"`
	ShippingState            *string   `json:"shipping_state,omitempty"`
	ShippingZip              *string   `json:"shipping_zip,omitempty"`
	ShippingCountry          *string   `json:"shipping_country,omitempty"`
	Status                   *string   `json:"status,omitempty"`
	IsTaxExempt              *bool     `json:"is_tax_exempt,omitempty"`
	TaxExemptionCert         *string   `json:"tax_exemption_cert,omitempty"`
	TaxExemptStartDate       *string   `json:"tax_exempt_start_date,omitempty"`
	TaxExemptEndDate         *string   `json:"tax_exempt_end_date,omitempty"`
	TaxExemptReason          *string   `json:"tax_exempt_reason,omitempty"`
	DefaultTaxJurisdictionID *string   `json:"default_tax_jurisdiction_id,omitempty"`
	IsActive                 *bool     `json:"is_active,omitempty"`
}

// ── Customer Certificate ──

type CustomerCertificate struct {
	ID         uuid.UUID `json:"id"`
	CustomerID uuid.UUID `json:"customer_id"`
	TenantID   uuid.UUID `json:"tenant_id"`
	CertType   string    `json:"cert_type"`
	FileName   string    `json:"file_name"`
	FilePath   string    `json:"file_path"`
	FileSize   int       `json:"file_size"`
	MimeType   string    `json:"mime_type"`
	UploadedAt time.Time `json:"uploaded_at"`
}
