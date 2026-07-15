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

func (s *GLService) ensureCreditMemoTables(ctx context.Context) error {
	if err := s.ensureIncomingPaymentTables(ctx); err != nil {
		return err
	}
	_, err := s.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS ar_credit_memos (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			memo_no VARCHAR(30) NOT NULL,
			customer_id UUID NOT NULL REFERENCES customers(id),
			memo_date DATE NOT NULL,
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			reason_code VARCHAR(60) NOT NULL DEFAULT '',
			amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			remaining_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
			journal_entry_id UUID REFERENCES gl_journal_entries(id),
			clearing_id UUID,
			description TEXT DEFAULT '',
			created_by UUID REFERENCES users(id),
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			UNIQUE(tenant_id, memo_no)
		);
		CREATE TABLE IF NOT EXISTS ar_credit_memo_clearings (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			clearing_no VARCHAR(30) NOT NULL,
			customer_id UUID NOT NULL REFERENCES customers(id),
			posting_date DATE NOT NULL,
			document_date DATE NOT NULL,
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			control_type VARCHAR(30) NOT NULL DEFAULT 'offset',
			credit_total NUMERIC(18,2) NOT NULL DEFAULT 0,
			invoice_applied_total NUMERIC(18,2) NOT NULL DEFAULT 0,
			net_balance NUMERIC(18,2) NOT NULL DEFAULT 0,
			status VARCHAR(30) NOT NULL DEFAULT 'POSTED',
			journal_entry_id UUID REFERENCES gl_journal_entries(id),
			description TEXT DEFAULT '',
			created_by UUID REFERENCES users(id),
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			UNIQUE(tenant_id, clearing_no)
		);
		CREATE TABLE IF NOT EXISTS ar_credit_memo_clearing_credits (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			clearing_id UUID NOT NULL REFERENCES ar_credit_memo_clearings(id) ON DELETE CASCADE,
			credit_memo_id UUID REFERENCES ar_credit_memos(id),
			reason_code VARCHAR(60) NOT NULL DEFAULT '',
			amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		);
		CREATE TABLE IF NOT EXISTS ar_credit_memo_clearing_invoices (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			clearing_id UUID NOT NULL REFERENCES ar_credit_memo_clearings(id) ON DELETE CASCADE,
			credit_memo_id UUID REFERENCES ar_credit_memos(id),
			invoice_id UUID NOT NULL REFERENCES sales_invoices(id),
			apply_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		);
		CREATE INDEX IF NOT EXISTS idx_ar_credit_memos_customer ON ar_credit_memos(tenant_id, customer_id, status);
		CREATE INDEX IF NOT EXISTS idx_ar_credit_clearings_customer ON ar_credit_memo_clearings(tenant_id, customer_id);
		CREATE INDEX IF NOT EXISTS idx_ar_credit_clear_inv ON ar_credit_memo_clearing_invoices(invoice_id);
	`)
	if err != nil {
		return fmt.Errorf("ensure credit memo tables: %w", err)
	}
	return nil
}

func (s *GLService) ListAROpenCreditMemos(ctx context.Context, tenantID, customerID uuid.UUID) ([]glmodels.ARCreditMemo, error) {
	if err := s.ensureCreditMemoTables(ctx); err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `SELECT cm.id, cm.memo_no, cm.customer_id,
			COALESCE(c.customer_code,''), COALESCE(c.name,''), cm.memo_date,
			COALESCE(cm.currency,'USD'), cm.reason_code, cm.amount::float8,
			cm.remaining_amount::float8, cm.status, COALESCE(cm.description,''),
			cm.journal_entry_id, cm.clearing_id, cm.created_at
		FROM ar_credit_memos cm
		LEFT JOIN customers c ON c.id=cm.customer_id
		WHERE cm.tenant_id=$1 AND cm.customer_id=$2
		  AND cm.status IN ('OPEN','PARTIAL')
		  AND cm.remaining_amount > 0
		ORDER BY cm.memo_date, cm.memo_no`, tenantID, customerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []glmodels.ARCreditMemo
	for rows.Next() {
		var cm glmodels.ARCreditMemo
		if err := rows.Scan(&cm.ID, &cm.MemoNo, &cm.CustomerID, &cm.CustomerCode, &cm.CustomerName,
			&cm.MemoDate, &cm.Currency, &cm.ReasonCode, &cm.Amount, &cm.RemainingAmount,
			&cm.Status, &cm.Description, &cm.JournalEntryID, &cm.ClearingID, &cm.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, cm)
	}
	return list, rows.Err()
}

func (s *GLService) CreateCreditMemoClearing(ctx context.Context, tenantID, userID uuid.UUID, req *glmodels.CreateCreditMemoClearingRequest) (*glmodels.CreditMemoClearingResult, error) {
	if err := s.ensureCreditMemoTables(ctx); err != nil {
		return nil, err
	}
	if len(req.NewCredits) == 0 && len(req.ExistingCreditMemoIDs) == 0 {
		return nil, fmt.Errorf("please add or select at least one credit memo")
	}
	req.Currency = strings.TrimSpace(req.Currency)
	if req.Currency == "" {
		req.Currency = "USD"
	}
	req.ControlType = strings.ToLower(strings.TrimSpace(req.ControlType))
	if req.ControlType == "" {
		req.ControlType = "offset"
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	orgID, err := firstActiveOrgTx(ctx, tx, tenantID)
	if err != nil {
		return nil, err
	}
	arAccountID, err := accountForAnyTypeTx(ctx, tx, orgID, "AR_RECON", "ar_recon")
	if err != nil {
		return nil, fmt.Errorf("no AR_RECON account configured in Finance Settings for org %s", orgID)
	}
	allowanceAccountID, err := accountForAnyTypeTx(ctx, tx, orgID, "SALES_RETURNS_ALLOWANCES", "SALES_ALLOWANCE", "SALES_REV", "sales_rev")
	if err != nil {
		allowanceAccountID, err = fallbackRevenueAccountTx(ctx, tx, tenantID)
		if err != nil {
			return nil, fmt.Errorf("no revenue or sales allowance account configured: %w", err)
		}
	}

	type creditState struct {
		id        uuid.UUID
		no        string
		remaining float64
		amount    float64
		currency  string
	}
	var credits []creditState
	createdMemoNos := []string{}
	newCreditTotal := 0.0
	for _, line := range req.NewCredits {
		amount := round2(line.Amount)
		if amount <= 0 {
			return nil, fmt.Errorf("credit amount must be greater than zero")
		}
		memoID := uuid.New()
		memoNo, err := nextCreditMemoNoTx(ctx, tx, tenantID, req.PostingDate)
		if err != nil {
			return nil, err
		}
		reason := strings.TrimSpace(line.ReasonCode)
		desc := strings.TrimSpace(line.Description)
		if desc == "" {
			desc = reason
		}
		if _, err := tx.Exec(ctx, `INSERT INTO ar_credit_memos
			(id, tenant_id, memo_no, customer_id, memo_date, currency, reason_code, amount, remaining_amount,
			 status, description, created_by, created_at, updated_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$8,'OPEN',$9,$10,NOW(),NOW())`,
			memoID, tenantID, memoNo, req.CustomerID, req.PostingDate, req.Currency, reason, amount, desc, userID); err != nil {
			return nil, fmt.Errorf("insert credit memo: %w", err)
		}
		credits = append(credits, creditState{id: memoID, no: memoNo, remaining: amount, amount: amount, currency: req.Currency})
		createdMemoNos = append(createdMemoNos, memoNo)
		newCreditTotal += amount
	}

	for _, memoID := range req.ExistingCreditMemoIDs {
		var c creditState
		if err := tx.QueryRow(ctx, `SELECT id, memo_no, remaining_amount::float8, amount::float8, COALESCE(currency,'USD')
			FROM ar_credit_memos
			WHERE id=$1 AND tenant_id=$2 AND customer_id=$3 AND status IN ('OPEN','PARTIAL') AND remaining_amount > 0
			FOR UPDATE`, memoID, tenantID, req.CustomerID).Scan(&c.id, &c.no, &c.remaining, &c.amount, &c.currency); err != nil {
			return nil, fmt.Errorf("load credit memo: %w", err)
		}
		if !strings.EqualFold(c.currency, req.Currency) {
			return nil, fmt.Errorf("currency mismatch for credit memo %s", c.no)
		}
		credits = append(credits, c)
	}

	type invoiceState struct {
		id        uuid.UUID
		no        string
		remaining float64
		want      float64
		applied   float64
		currency  string
	}
	invoiceByID := map[uuid.UUID]float64{}
	for _, inv := range req.Invoices {
		invoiceByID[inv.InvoiceID] += inv.ApplyAmount
	}
	var invoices []invoiceState
	for invoiceID, want := range invoiceByID {
		var inv invoiceState
		if err := tx.QueryRow(ctx, `SELECT id, invoice_no, COALESCE(remaining_amount,total_amount)::float8, COALESCE(currency,'USD')
			FROM sales_invoices
			WHERE id=$1 AND tenant_id=$2 AND customer_id=$3 AND status IN ('POSTED','PARTIALLY_CLEARED')
			  AND COALESCE(remaining_amount,total_amount) > 0
			FOR UPDATE`, invoiceID, tenantID, req.CustomerID).Scan(&inv.id, &inv.no, &inv.remaining, &inv.currency); err != nil {
			return nil, fmt.Errorf("load invoice for credit memo clearing: %w", err)
		}
		if !strings.EqualFold(inv.currency, req.Currency) {
			return nil, fmt.Errorf("currency mismatch for invoice %s", inv.no)
		}
		inv.want = round2(want)
		if inv.want <= 0 {
			return nil, fmt.Errorf("apply amount must be greater than zero for invoice %s", inv.no)
		}
		if inv.want-inv.remaining > 0.01 {
			return nil, fmt.Errorf("apply amount %.2f exceeds remaining %.2f for invoice %s", inv.want, inv.remaining, inv.no)
		}
		invoices = append(invoices, inv)
	}

	creditTotal := 0.0
	for _, c := range credits {
		creditTotal += c.remaining
	}
	creditTotal = round2(creditTotal)

	clearingID := uuid.New()
	clearingNo, err := nextCreditClearingNoTx(ctx, tx, tenantID, req.PostingDate)
	if err != nil {
		return nil, err
	}
	description := strings.TrimSpace(req.Description)
	if description == "" {
		description = fmt.Sprintf("Credit memo clearing %s", clearingNo)
	}

	journalEntryID := uuid.Nil
	journalDocNo := ""
	if newCreditTotal > 0 {
		lines := []journalLineForPayment{
			{accountID: allowanceAccountID, debit: round2(newCreditTotal), description: fmt.Sprintf("Credit memo allowance %s", clearingNo)},
			{accountID: arAccountID, credit: round2(newCreditTotal), description: fmt.Sprintf("Credit memo AR credit %s", clearingNo)},
		}
		journalEntryID, journalDocNo, err = insertPostedJournalForPaymentTx(ctx, tx, tenantID, userID, orgID, req.PostingDate, description, clearingNo, lines)
		if err != nil {
			return nil, err
		}
		if _, err := tx.Exec(ctx, `UPDATE ar_credit_memos
			SET journal_entry_id=$4, updated_at=NOW()
			WHERE tenant_id=$1 AND customer_id=$2 AND memo_no=ANY($3)`,
			tenantID, req.CustomerID, createdMemoNos, journalEntryID); err != nil {
			return nil, fmt.Errorf("update credit memo journal: %w", err)
		}
	}

	if _, err := tx.Exec(ctx, `INSERT INTO ar_credit_memo_clearings
		(id, tenant_id, clearing_no, customer_id, posting_date, document_date, currency, control_type,
		 credit_total, invoice_applied_total, net_balance, status, journal_entry_id, description, created_by, created_at, updated_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,0,0,0,'POSTED',$9,$10,$11,NOW(),NOW())`,
		clearingID, tenantID, clearingNo, req.CustomerID, req.PostingDate, req.DocumentDate, req.Currency,
		req.ControlType, nilUUID(journalEntryID), description, userID); err != nil {
		return nil, fmt.Errorf("insert credit clearing: %w", err)
	}
	for _, c := range credits {
		if _, err := tx.Exec(ctx, `INSERT INTO ar_credit_memo_clearing_credits
			(id, clearing_id, credit_memo_id, reason_code, amount, created_at)
			SELECT $1,$2,id,reason_code,$4,NOW() FROM ar_credit_memos WHERE id=$3`,
			uuid.New(), clearingID, c.id, c.remaining); err != nil {
			return nil, fmt.Errorf("insert credit clearing credit: %w", err)
		}
	}

	invoiceAppliedTotal := 0.0
	for ci := range credits {
		creditLeft := credits[ci].remaining
		for ii := range invoices {
			invoiceNeed := invoices[ii].want - invoices[ii].applied
			if creditLeft <= 0.01 || invoiceNeed <= 0.01 {
				continue
			}
			apply := math.Min(creditLeft, invoiceNeed)
			apply = round2(apply)
			if apply <= 0 {
				continue
			}
			creditLeft = round2(creditLeft - apply)
			invoices[ii].applied = round2(invoices[ii].applied + apply)
			invoiceAppliedTotal = round2(invoiceAppliedTotal + apply)
			if _, err := tx.Exec(ctx, `INSERT INTO ar_credit_memo_clearing_invoices
				(id, clearing_id, credit_memo_id, invoice_id, apply_amount, created_at)
				VALUES($1,$2,$3,$4,$5,NOW())`,
				uuid.New(), clearingID, credits[ci].id, invoices[ii].id, apply); err != nil {
				return nil, fmt.Errorf("insert credit clearing invoice: %w", err)
			}
		}
		credits[ci].remaining = creditLeft
	}
	if len(invoices) > 0 && invoiceAppliedTotal <= 0 {
		return nil, fmt.Errorf("selected invoices could not be matched with available credit")
	}
	if req.ControlType == "offset" && len(invoices) > 0 {
		requestedInvoiceTotal := 0.0
		for _, inv := range invoices {
			requestedInvoiceTotal += inv.want
		}
		if invoiceAppliedTotal+0.01 < requestedInvoiceTotal && !req.AllowPartial {
			return nil, fmt.Errorf("credit is not enough to clear selected invoices; enable partial clearing or reduce invoice selection")
		}
	}

	for _, inv := range invoices {
		if inv.applied <= 0 {
			continue
		}
		remaining := round2(inv.remaining - inv.applied)
		status := "PARTIALLY_CLEARED"
		clearingStatus := "PARTIAL"
		if remaining <= 0.01 {
			remaining = 0
			status = "CLEARED"
			clearingStatus = "CLEARED"
		}
		if _, err := tx.Exec(ctx, `UPDATE sales_invoices
			SET remaining_amount=$3, clearing_status=$4, status=$5, clearing_voucher_id=$6, updated_at=NOW()
			WHERE id=$1 AND tenant_id=$2`, inv.id, tenantID, remaining, clearingStatus, status, clearingID); err != nil {
			return nil, fmt.Errorf("update invoice for credit clearing: %w", err)
		}
		if remaining == 0 {
			_, _ = tx.Exec(ctx, `UPDATE gl_journal_lines l
				SET open_item_status='cleared', clearing_doc_id=$3, clearing_date=$4, cleared_at=NOW()
				FROM sales_invoices si
				WHERE si.journal_entry_id=l.entry_id AND si.id=$1 AND si.tenant_id=$2
				  AND l.account_id=$5 AND COALESCE(l.open_item_status,'open')='open'`,
				inv.id, tenantID, clearingID, req.PostingDate, arAccountID)
		}
	}

	for _, c := range credits {
		status := "PARTIAL"
		if c.remaining <= 0.01 {
			c.remaining = 0
			status = "CLEARED"
		}
		if _, err := tx.Exec(ctx, `UPDATE ar_credit_memos
			SET remaining_amount=$3, status=$4, clearing_id=$5, updated_at=NOW()
			WHERE id=$1 AND tenant_id=$2`, c.id, tenantID, c.remaining, status, clearingID); err != nil {
			return nil, fmt.Errorf("update credit memo remaining: %w", err)
		}
	}

	netBalance := round2(invoiceAppliedTotal - creditTotal)
	if _, err := tx.Exec(ctx, `UPDATE ar_credit_memo_clearings
		SET credit_total=$3, invoice_applied_total=$4, net_balance=$5, updated_at=NOW()
		WHERE id=$1 AND tenant_id=$2`, clearingID, tenantID, creditTotal, invoiceAppliedTotal, netBalance); err != nil {
		return nil, fmt.Errorf("update credit clearing totals: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &glmodels.CreditMemoClearingResult{
		ClearingID:          clearingID,
		ClearingNo:          clearingNo,
		JournalEntryID:      journalEntryID,
		JournalDocNo:        journalDocNo,
		CreditTotal:         creditTotal,
		InvoiceAppliedTotal: invoiceAppliedTotal,
		NetBalance:          netBalance,
		Status:              "POSTED",
		CreatedMemos:        createdMemoNos,
	}, nil
}

func firstActiveOrgTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID) (uuid.UUID, error) {
	var orgID uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT id FROM organizations WHERE tenant_id=$1 AND is_active=true ORDER BY org_code LIMIT 1`, tenantID).Scan(&orgID); err != nil {
		return uuid.Nil, fmt.Errorf("no active organization found: %w", err)
	}
	return orgID, nil
}

func fallbackRevenueAccountTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID) (uuid.UUID, error) {
	var accountID uuid.UUID
	err := tx.QueryRow(ctx, `SELECT id FROM gl_accounts
		WHERE tenant_id=$1 AND is_leaf=true AND is_active=true
		  AND UPPER(account_type)='REVENUE'
		ORDER BY account_code
		LIMIT 1`, tenantID).Scan(&accountID)
	return accountID, err
}

func nextCreditMemoNoTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID, postingDate time.Time) (string, error) {
	prefix := "CM" + postingDate.Format("20060102")
	var seq int
	if err := tx.QueryRow(ctx, `SELECT COALESCE(MAX(SUBSTRING(memo_no FROM '.{4}$')::int),0)+1
		FROM ar_credit_memos WHERE tenant_id=$1 AND memo_no LIKE $2`, tenantID, prefix+"%").Scan(&seq); err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%04d", prefix, seq), nil
}

func nextCreditClearingNoTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID, postingDate time.Time) (string, error) {
	prefix := "CMC" + postingDate.Format("20060102")
	var seq int
	if err := tx.QueryRow(ctx, `SELECT COALESCE(MAX(SUBSTRING(clearing_no FROM '.{4}$')::int),0)+1
		FROM ar_credit_memo_clearings WHERE tenant_id=$1 AND clearing_no LIKE $2`, tenantID, prefix+"%").Scan(&seq); err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%04d", prefix, seq), nil
}

func nilUUID(id uuid.UUID) any {
	if id == uuid.Nil {
		return nil
	}
	return id
}
