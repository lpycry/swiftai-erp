package service

import (
	"context"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
)

func (s *GLService) ensureIncomingPaymentTables(ctx context.Context) error {
	_, err := s.db.Exec(ctx, `
		ALTER TABLE sales_invoices
			ADD COLUMN IF NOT EXISTS remaining_amount NUMERIC(18,2),
			ADD COLUMN IF NOT EXISTS clearing_status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
			ADD COLUMN IF NOT EXISTS clearing_voucher_id UUID;
		UPDATE sales_invoices
		SET remaining_amount = COALESCE(remaining_amount, total_amount),
			clearing_status = CASE
				WHEN COALESCE(remaining_amount, total_amount) <= 0 THEN 'CLEARED'
				WHEN status = 'PARTIALLY_CLEARED' THEN 'PARTIAL'
				ELSE 'OPEN'
			END
		WHERE status <> 'CANCELLED';
		CREATE TABLE IF NOT EXISTS ar_receipt_vouchers (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			voucher_no VARCHAR(30) NOT NULL,
			customer_id UUID NOT NULL REFERENCES customers(id),
			bank_account_id UUID NOT NULL REFERENCES gl_accounts(id),
			receipt_date DATE NOT NULL,
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			exchange_rate NUMERIC(18,6) NOT NULL DEFAULT 1,
			net_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			diff_type VARCHAR(40) NOT NULL DEFAULT '',
			diff_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			applied_total NUMERIC(18,2) NOT NULL DEFAULT 0,
			status VARCHAR(30) NOT NULL DEFAULT 'POSTED',
			journal_entry_id UUID REFERENCES gl_journal_entries(id),
			description TEXT DEFAULT '',
			created_by UUID REFERENCES users(id),
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			UNIQUE(tenant_id, voucher_no)
		);
		CREATE TABLE IF NOT EXISTS ar_receipt_applications (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			voucher_id UUID NOT NULL REFERENCES ar_receipt_vouchers(id) ON DELETE CASCADE,
			invoice_id UUID NOT NULL REFERENCES sales_invoices(id),
			apply_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		);
		CREATE INDEX IF NOT EXISTS idx_ar_receipts_customer ON ar_receipt_vouchers(tenant_id, customer_id);
		CREATE INDEX IF NOT EXISTS idx_ar_receipt_apps_invoice ON ar_receipt_applications(invoice_id);
	`)
	if err != nil {
		return fmt.Errorf("ensure incoming payment tables: %w", err)
	}
	return nil
}

func (s *GLService) ListARCustomers(ctx context.Context, tenantID uuid.UUID, query string) ([]glmodels.ARCustomer, error) {
	if err := s.ensureIncomingPaymentTables(ctx); err != nil {
		return nil, err
	}
	pattern := "%" + strings.TrimSpace(query) + "%"
	rows, err := s.db.Query(ctx, `SELECT id, COALESCE(customer_code,''), name, COALESCE(currency,'USD')
		FROM customers
		WHERE tenant_id=$1 AND is_active=true
		  AND ($2='' OR customer_code ILIKE $3 OR name ILIKE $3)
		ORDER BY customer_code, name
		LIMIT 80`, tenantID, strings.TrimSpace(query), pattern)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []glmodels.ARCustomer
	for rows.Next() {
		var c glmodels.ARCustomer
		if err := rows.Scan(&c.ID, &c.CustomerCode, &c.Name, &c.Currency); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, rows.Err()
}

func (s *GLService) ListAROpenInvoices(ctx context.Context, tenantID, customerID uuid.UUID) ([]glmodels.AROpenInvoice, error) {
	if err := s.ensureIncomingPaymentTables(ctx); err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `SELECT si.id, si.invoice_no, si.invoice_date, si.customer_id,
			COALESCE(c.customer_code,''), COALESCE(c.name,''), COALESCE(si.currency,'USD'),
			si.total_amount::float8, COALESCE(si.remaining_amount, si.total_amount)::float8,
			GREATEST((CURRENT_DATE - si.invoice_date),0)::int,
			COALESCE(si.invoice_no || ' / SO ' || so.so_number, si.invoice_no),
			COALESCE(si.clearing_status,'OPEN')
		FROM sales_invoices si
		LEFT JOIN customers c ON c.id=si.customer_id
		LEFT JOIN sales_orders so ON so.id=si.sales_order_id
		WHERE si.tenant_id=$1 AND si.customer_id=$2
		  AND si.status IN ('POSTED','PARTIALLY_CLEARED')
		  AND COALESCE(si.remaining_amount, si.total_amount) > 0
		ORDER BY si.invoice_date, si.invoice_no`, tenantID, customerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []glmodels.AROpenInvoice
	for rows.Next() {
		var inv glmodels.AROpenInvoice
		if err := rows.Scan(&inv.ID, &inv.InvoiceNo, &inv.InvoiceDate, &inv.CustomerID,
			&inv.CustomerCode, &inv.CustomerName, &inv.Currency, &inv.TotalAmount,
			&inv.RemainingAmount, &inv.AgeDays, &inv.Reference, &inv.Status); err != nil {
			return nil, err
		}
		list = append(list, inv)
	}
	return list, rows.Err()
}

func (s *GLService) CreateIncomingPayment(ctx context.Context, tenantID, userID uuid.UUID, req *glmodels.CreateIncomingPaymentRequest) (*glmodels.IncomingPaymentResult, error) {
	if err := s.ensureIncomingPaymentTables(ctx); err != nil {
		return nil, err
	}
	if len(req.Applications) == 0 {
		return nil, fmt.Errorf("please select at least one invoice")
	}
	if req.ExchangeRate <= 0 {
		req.ExchangeRate = 1
	}
	req.Currency = strings.TrimSpace(req.Currency)
	if req.Currency == "" {
		req.Currency = "USD"
	}
	req.DiffType = strings.TrimSpace(req.DiffType)
	if req.DiffAmount < 0 {
		return nil, fmt.Errorf("diff amount cannot be negative")
	}

	appliedTotal := 0.0
	for _, app := range req.Applications {
		appliedTotal += app.ApplyAmount
	}
	appliedTotal = round2(appliedTotal)
	diff := round2(req.NetAmount + req.DiffAmount - appliedTotal)
	if math.Abs(diff) > clearingTolerance {
		return nil, fmt.Errorf("applied invoice amount does not match net receipt plus differences; difference %.2f", diff)
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var orgID uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT COALESCE(o.id, (SELECT id FROM organizations WHERE tenant_id=$2 AND is_active=true LIMIT 1))
		FROM gl_accounts ga
		LEFT JOIN org_reconciliation_accounts ora ON ora.account_id=ga.id
		LEFT JOIN organizations o ON o.id=ora.org_id
		WHERE ga.id=$1 AND ga.tenant_id=$2
		LIMIT 1`, req.BankAccountID, tenantID).Scan(&orgID); err != nil || orgID == uuid.Nil {
		if err := tx.QueryRow(ctx, `SELECT id FROM organizations WHERE tenant_id=$1 AND is_active=true LIMIT 1`, tenantID).Scan(&orgID); err != nil {
			return nil, fmt.Errorf("no active organization found: %w", err)
		}
	}
	arAccountID, err := accountForAnyTypeTx(ctx, tx, orgID, "AR_RECON", "ar_recon")
	if err != nil {
		return nil, fmt.Errorf("no AR_RECON account configured in Finance Settings for org %s", orgID)
	}

	type invState struct {
		id        uuid.UUID
		no        string
		remaining float64
		apply     float64
	}
	appByInvoice := map[uuid.UUID]float64{}
	for _, app := range req.Applications {
		appByInvoice[app.InvoiceID] += app.ApplyAmount
	}
	var invoices []invState
	for invoiceID, applyAmount := range appByInvoice {
		var inv invState
		if err := tx.QueryRow(ctx, `SELECT id, invoice_no, COALESCE(remaining_amount,total_amount)::float8
			FROM sales_invoices
			WHERE id=$1 AND tenant_id=$2 AND customer_id=$3 AND status IN ('POSTED','PARTIALLY_CLEARED')
			FOR UPDATE`, invoiceID, tenantID, req.CustomerID).Scan(&inv.id, &inv.no, &inv.remaining); err != nil {
			return nil, fmt.Errorf("load invoice for payment: %w", err)
		}
		inv.apply = round2(applyAmount)
		if inv.apply <= 0 {
			return nil, fmt.Errorf("apply amount must be greater than zero for invoice %s", inv.no)
		}
		if inv.apply-inv.remaining > 0.01 {
			return nil, fmt.Errorf("apply amount %.2f exceeds remaining %.2f for invoice %s", inv.apply, inv.remaining, inv.no)
		}
		invoices = append(invoices, inv)
	}

	diffAccountID := uuid.Nil
	if req.DiffAmount > 0 {
		diffAccountID, err = accountForAnyTypeTx(ctx, tx, orgID, diffAccountTypes(req.DiffType)...)
		if err != nil {
			diffAccountID, err = fallbackExpenseAccountTx(ctx, tx, tenantID)
			if err != nil {
				return nil, fmt.Errorf("no expense account available for diff amount: %w", err)
			}
		}
	}

	voucherID := uuid.New()
	voucherNo, err := nextIncomingPaymentNoTx(ctx, tx, tenantID, req.ReceiptDate)
	if err != nil {
		return nil, err
	}
	description := strings.TrimSpace(req.Description)
	if description == "" {
		description = fmt.Sprintf("Incoming payment %s", voucherNo)
	}
	lines := []journalLineForPayment{
		{accountID: req.BankAccountID, debit: req.NetAmount, description: fmt.Sprintf("Incoming payment bank %s", voucherNo)},
	}
	if req.DiffAmount > 0 {
		lines = append(lines, journalLineForPayment{accountID: diffAccountID, debit: req.DiffAmount, description: fmt.Sprintf("%s %s", diffLabel(req.DiffType), voucherNo)})
	}
	lines = append(lines, journalLineForPayment{accountID: arAccountID, credit: appliedTotal, description: fmt.Sprintf("AR clearing %s", voucherNo)})
	entryID, journalNo, err := insertPostedJournalForPaymentTx(ctx, tx, tenantID, userID, orgID, req.ReceiptDate, description, voucherNo, lines)
	if err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO ar_receipt_vouchers
		(id, tenant_id, voucher_no, customer_id, bank_account_id, receipt_date, currency, exchange_rate,
		 net_amount, diff_type, diff_amount, applied_total, status, journal_entry_id, description, created_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'POSTED',$13,$14,$15,NOW(),NOW())`,
		voucherID, tenantID, voucherNo, req.CustomerID, req.BankAccountID, req.ReceiptDate, req.Currency, req.ExchangeRate,
		req.NetAmount, req.DiffType, req.DiffAmount, appliedTotal, entryID, description, userID); err != nil {
		return nil, fmt.Errorf("insert receipt voucher: %w", err)
	}
	for _, inv := range invoices {
		remaining := round2(inv.remaining - inv.apply)
		status := "PARTIALLY_CLEARED"
		clearingStatus := "PARTIAL"
		if remaining <= 0.01 {
			remaining = 0
			status = "CLEARED"
			clearingStatus = "CLEARED"
		}
		if _, err := tx.Exec(ctx, `INSERT INTO ar_receipt_applications(id, voucher_id, invoice_id, apply_amount, created_at)
			VALUES($1,$2,$3,$4,NOW())`, uuid.New(), voucherID, inv.id, inv.apply); err != nil {
			return nil, fmt.Errorf("insert receipt application: %w", err)
		}
		if _, err := tx.Exec(ctx, `UPDATE sales_invoices
			SET remaining_amount=$3, clearing_status=$4, status=$5, clearing_voucher_id=$6, updated_at=NOW()
			WHERE id=$1 AND tenant_id=$2`, inv.id, tenantID, remaining, clearingStatus, status, voucherID); err != nil {
			return nil, fmt.Errorf("update invoice remaining: %w", err)
		}
		if remaining == 0 {
			_, _ = tx.Exec(ctx, `UPDATE gl_journal_lines l
				SET open_item_status='cleared', clearing_doc_id=$3, clearing_date=$4, cleared_at=NOW()
				FROM sales_invoices si
				WHERE si.journal_entry_id=l.entry_id AND si.id=$1 AND si.tenant_id=$2
				  AND l.account_id=$5 AND COALESCE(l.open_item_status,'open')='open'`,
				inv.id, tenantID, entryID, req.ReceiptDate, arAccountID)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &glmodels.IncomingPaymentResult{
		VoucherID:      voucherID,
		VoucherNo:      voucherNo,
		JournalEntryID: entryID,
		JournalDocNo:   journalNo,
		AppliedTotal:   appliedTotal,
		Difference:     diff,
	}, nil
}

func diffAccountTypes(diffType string) []string {
	key := strings.ToLower(strings.ReplaceAll(strings.TrimSpace(diffType), " ", "_"))
	switch key {
	case "exchange", "exchange_loss", "fx", "fx_loss", "汇兑损益":
		return []string{"EXCHANGE_GAIN_LOSS", "FX_LOSS", "PRICE_DIFF"}
	case "short", "short_pay", "discount", "短期尾差折让":
		return []string{"CASH_DISCOUNT", "PRICE_DIFF"}
	default:
		return []string{"BANK_FEES", "BANK_FEE", "FINANCE_FEE", "PRICE_DIFF"}
	}
}

func diffLabel(diffType string) string {
	if strings.TrimSpace(diffType) == "" {
		return "Payment difference"
	}
	return diffType
}

func accountForAnyTypeTx(ctx context.Context, tx pgx.Tx, orgID uuid.UUID, accountTypes ...string) (uuid.UUID, error) {
	for _, accountType := range accountTypes {
		var accountID uuid.UUID
		err := tx.QueryRow(ctx, `SELECT account_id
			FROM org_reconciliation_accounts
			WHERE org_id=$1 AND LOWER(account_type)=LOWER($2)
			LIMIT 1`, orgID, accountType).Scan(&accountID)
		if err == nil && accountID != uuid.Nil {
			return accountID, nil
		}
	}
	return uuid.Nil, fmt.Errorf("account types %v not configured", accountTypes)
}

func fallbackExpenseAccountTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID) (uuid.UUID, error) {
	var accountID uuid.UUID
	err := tx.QueryRow(ctx, `SELECT id FROM gl_accounts
		WHERE tenant_id=$1 AND is_leaf=true AND is_active=true
		  AND account_type IN ('EXPENSE','OTHER_EXPENSE')
		ORDER BY CASE WHEN account_code IN ('6910','6800') THEN 0 ELSE 1 END, account_code
		LIMIT 1`, tenantID).Scan(&accountID)
	return accountID, err
}

func nextIncomingPaymentNoTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID, receiptDate time.Time) (string, error) {
	prefix := "RCPT" + receiptDate.Format("20060102")
	var seq int
	if err := tx.QueryRow(ctx, `SELECT COALESCE(MAX(SUBSTRING(voucher_no FROM '.{4}$')::int),0)+1
		FROM ar_receipt_vouchers WHERE tenant_id=$1 AND voucher_no LIKE $2`, tenantID, prefix+"%").Scan(&seq); err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%04d", prefix, seq), nil
}

type journalLineForPayment struct {
	accountID   uuid.UUID
	debit       float64
	credit      float64
	description string
}

func insertPostedJournalForPaymentTx(ctx context.Context, tx pgx.Tx, tenantID, userID, orgID uuid.UUID, postingDate time.Time, description, reference string, lines []journalLineForPayment) (uuid.UUID, string, error) {
	periodID, err := derivePeriodForPaymentTx(ctx, tx, tenantID, orgID, postingDate)
	if err != nil {
		return uuid.Nil, "", err
	}
	totalDebit := 0.0
	totalCredit := 0.0
	for _, line := range lines {
		totalDebit += line.debit
		totalCredit += line.credit
	}
	if math.Abs(totalDebit-totalCredit) > 0.01 {
		return uuid.Nil, "", fmt.Errorf("journal is not balanced: debit %.2f credit %.2f", totalDebit, totalCredit)
	}
	entryID := uuid.New()
	documentNo, err := nextGLDocumentNoForPaymentTx(ctx, tx, tenantID)
	if err != nil {
		return uuid.Nil, "", err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO gl_journal_entries
		(id, tenant_id, organization_id, document_no, posting_date, document_date, period_id,
		 description, reference, entry_type, status, source, created_by, created_at, posted_at, posted_by)
		VALUES ($1,$2,$3,$4,$5,$5,$6,$7,$8,'normal','posted','bank',$9,NOW(),NOW(),$9)`,
		entryID, tenantID, orgID, documentNo, postingDate, periodID, description, reference, userID); err != nil {
		return uuid.Nil, "", fmt.Errorf("insert payment journal header: %w", err)
	}
	for _, line := range lines {
		if _, err := tx.Exec(ctx, `INSERT INTO gl_journal_lines
			(id, entry_id, account_id, account_code, account_name, debit, credit, description, open_item_status)
			VALUES ($1,$2,$3,
				(SELECT account_code FROM gl_accounts WHERE id=$3),
				(SELECT account_name FROM gl_accounts WHERE id=$3),
				$4,$5,$6,'not_managed')`,
			uuid.New(), entryID, line.accountID, line.debit, line.credit, line.description); err != nil {
			return uuid.Nil, "", fmt.Errorf("insert payment journal line: %w", err)
		}
		if err := updateAccountBalanceForPaymentTx(ctx, tx, tenantID, line.accountID, periodID, line.debit, line.credit); err != nil {
			return uuid.Nil, "", err
		}
	}
	return entryID, documentNo, nil
}

func derivePeriodForPaymentTx(ctx context.Context, tx pgx.Tx, tenantID, orgID uuid.UUID, postingDate time.Time) (uuid.UUID, error) {
	var periodID uuid.UUID
	if orgID != uuid.Nil {
		if err := tx.QueryRow(ctx, `SELECT id FROM gl_periods
			WHERE tenant_id=$1 AND organization_id=$2 AND start_date <= $3 AND end_date >= $3 AND is_open=true AND is_locked=false
			LIMIT 1`, tenantID, orgID, postingDate).Scan(&periodID); err == nil {
			return periodID, nil
		}
	}
	if err := tx.QueryRow(ctx, `SELECT id FROM gl_periods
		WHERE tenant_id=$1 AND start_date <= $2 AND end_date >= $2 AND is_open=true AND is_locked=false
		LIMIT 1`, tenantID, postingDate).Scan(&periodID); err != nil {
		return uuid.Nil, fmt.Errorf("no open period found for %s: %w", postingDate.Format("2006-01-02"), err)
	}
	return periodID, nil
}

func nextGLDocumentNoForPaymentTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID) (string, error) {
	now := time.Now()
	prefix := fmt.Sprintf("GL-%s-", now.Format("200601"))
	var seq int
	err := tx.QueryRow(ctx, `INSERT INTO gl_document_seq (tenant_id, prefix, seq)
		VALUES ($1, $2, 1)
		ON CONFLICT (tenant_id, prefix) DO UPDATE SET seq = gl_document_seq.seq + 1
		RETURNING gl_document_seq.seq`, tenantID, prefix).Scan(&seq)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%04d", prefix, seq), nil
}

func updateAccountBalanceForPaymentTx(ctx context.Context, tx pgx.Tx, tenantID, accountID, periodID uuid.UUID, debit, credit float64) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO gl_account_balances (tenant_id, account_id, period_id, opening_balance, period_debit, period_credit, closing_balance, updated_at)
		SELECT $1, $2, $3,
		       COALESCE((SELECT ab.closing_balance FROM gl_account_balances ab JOIN gl_periods p ON p.id=ab.period_id
		                 WHERE ab.tenant_id=$1 AND ab.account_id=$2 AND (p.fiscal_year < cur.fiscal_year OR (p.fiscal_year=cur.fiscal_year AND p.period_no < cur.period_no))
		                 ORDER BY p.fiscal_year DESC, p.period_no DESC LIMIT 1),0),
		       COALESCE(ab2.period_debit,0)+$4,
		       COALESCE(ab2.period_credit,0)+$5,
		       COALESCE((SELECT ab.closing_balance FROM gl_account_balances ab JOIN gl_periods p ON p.id=ab.period_id
		                 WHERE ab.tenant_id=$1 AND ab.account_id=$2 AND (p.fiscal_year < cur.fiscal_year OR (p.fiscal_year=cur.fiscal_year AND p.period_no < cur.period_no))
		                 ORDER BY p.fiscal_year DESC, p.period_no DESC LIMIT 1),0) + COALESCE(ab2.period_debit,0)+$4-COALESCE(ab2.period_credit,0)-$5,
		       NOW()
		FROM gl_periods cur
		LEFT JOIN gl_account_balances ab2 ON ab2.period_id=cur.id AND ab2.account_id=$2 AND ab2.tenant_id=$1
		WHERE cur.id=$3
		ON CONFLICT (tenant_id, account_id, period_id) DO UPDATE SET
		    period_debit=gl_account_balances.period_debit+$4,
		    period_credit=gl_account_balances.period_credit+$5,
		    closing_balance=gl_account_balances.opening_balance + (gl_account_balances.period_debit+$4) - (gl_account_balances.period_credit+$5),
		    updated_at=NOW()`, tenantID, accountID, periodID, debit, credit)
	if err != nil {
		return fmt.Errorf("update payment balance for account %s: %w", accountID, err)
	}
	return nil
}
