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

const clearingTolerance = 0.01

func (s *GLService) ensureClearingColumns(ctx context.Context) error {
	_, err := s.db.Exec(ctx, `
		ALTER TABLE gl_accounts
			ADD COLUMN IF NOT EXISTS open_item_managed BOOLEAN NOT NULL DEFAULT false;
		UPDATE gl_accounts
		SET open_item_managed = true
		WHERE open_item_managed = false
		  AND (
		    COALESCE(reconciliation_type,'none') IN ('customer','vendor')
		    OR account_code IN ('1125','2190')
		    OR lower(account_name) LIKE '%clearing%'
		    OR lower(account_name) LIKE '%gr/ir%'
		  );
		ALTER TABLE gl_journal_lines
			ADD COLUMN IF NOT EXISTS open_item_status VARCHAR(20) NOT NULL DEFAULT 'open',
			ADD COLUMN IF NOT EXISTS clearing_doc_id UUID REFERENCES gl_journal_entries(id),
			ADD COLUMN IF NOT EXISTS clearing_date DATE,
			ADD COLUMN IF NOT EXISTS cleared_at TIMESTAMPTZ;
		UPDATE gl_journal_lines l
		SET open_item_status = 'not_managed'
		FROM gl_accounts a
		WHERE l.account_id = a.id
		  AND a.open_item_managed = false
		  AND COALESCE(l.open_item_status,'open') = 'open';
		CREATE INDEX IF NOT EXISTS idx_gl_lines_open_items
			ON gl_journal_lines(account_id, open_item_status);
		CREATE INDEX IF NOT EXISTS idx_gl_lines_clearing_doc
			ON gl_journal_lines(clearing_doc_id);
	`)
	if err != nil {
		return fmt.Errorf("ensure clearing columns: %w", err)
	}
	return nil
}

func (s *GLService) ListOpenItems(ctx context.Context, tenantID, accountID uuid.UUID) ([]glmodels.OpenItem, error) {
	if err := s.ensureClearingColumns(ctx); err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `
		SELECT l.id, l.entry_id, e.document_no, e.posting_date, l.account_id, l.account_code, l.account_name,
			l.partner_id, COALESCE(l.partner_type,''), l.debit::float8, l.credit::float8,
			COALESCE(a.currency,'USD'), COALESCE(l.description,''), COALESCE(e.reference,''),
			COALESCE(l.open_item_status,'open')
		FROM gl_journal_lines l
		JOIN gl_journal_entries e ON e.id = l.entry_id
		JOIN gl_accounts a ON a.id = l.account_id
		WHERE e.tenant_id = $1
		  AND e.status = 'posted'
		  AND l.account_id = $2
		  AND a.open_item_managed = true
		  AND COALESCE(l.open_item_status,'open') = 'open'
		  AND (COALESCE(l.debit,0) <> 0 OR COALESCE(l.credit,0) <> 0)
		ORDER BY e.posting_date, e.document_no, l.id`, tenantID, accountID)
	if err != nil {
		return nil, fmt.Errorf("list open items: %w", err)
	}
	defer rows.Close()

	items := []glmodels.OpenItem{}
	for rows.Next() {
		var item glmodels.OpenItem
		if err := rows.Scan(&item.LineID, &item.EntryID, &item.DocumentNo, &item.PostingDate,
			&item.AccountID, &item.AccountCode, &item.AccountName, &item.PartnerID, &item.PartnerType,
			&item.Debit, &item.Credit, &item.Currency, &item.Description, &item.Reference, &item.OpenItemStatus); err != nil {
			return nil, err
		}
		item.AmountSigned = round2(item.Debit - item.Credit)
		if item.AmountSigned >= 0 {
			item.OriginalSide = "debit"
		} else {
			item.OriginalSide = "credit"
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *GLService) ListClearedItems(ctx context.Context, tenantID, accountID uuid.UUID) ([]glmodels.OpenItem, error) {
	if err := s.ensureClearingColumns(ctx); err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `
		SELECT l.id, l.entry_id, e.document_no, e.posting_date, l.account_id, l.account_code, l.account_name,
			l.partner_id, COALESCE(l.partner_type,''), l.debit::float8, l.credit::float8,
			COALESCE(a.currency,'USD'), COALESCE(l.description,''), COALESCE(e.reference,''),
			COALESCE(l.open_item_status,'open'), l.clearing_doc_id,
			COALESCE(ce.document_no,''), l.clearing_date, l.cleared_at
		FROM gl_journal_lines l
		JOIN gl_journal_entries e ON e.id = l.entry_id
		JOIN gl_accounts a ON a.id = l.account_id
		LEFT JOIN gl_journal_entries ce ON ce.id = l.clearing_doc_id
		WHERE e.tenant_id = $1
		  AND e.status = 'posted'
		  AND l.account_id = $2
		  AND a.open_item_managed = true
		  AND COALESCE(l.open_item_status,'open') = 'cleared'
		  AND l.clearing_doc_id IS NOT NULL
		  AND l.entry_id <> l.clearing_doc_id
		  AND (COALESCE(l.debit,0) <> 0 OR COALESCE(l.credit,0) <> 0)
		ORDER BY COALESCE(l.clearing_date, e.posting_date) DESC, ce.document_no DESC, e.document_no, l.id`, tenantID, accountID)
	if err != nil {
		return nil, fmt.Errorf("list cleared items: %w", err)
	}
	defer rows.Close()

	items := []glmodels.OpenItem{}
	for rows.Next() {
		var item glmodels.OpenItem
		if err := rows.Scan(&item.LineID, &item.EntryID, &item.DocumentNo, &item.PostingDate,
			&item.AccountID, &item.AccountCode, &item.AccountName, &item.PartnerID, &item.PartnerType,
			&item.Debit, &item.Credit, &item.Currency, &item.Description, &item.Reference, &item.OpenItemStatus,
			&item.ClearingDocID, &item.ClearingDocNo, &item.ClearingDate, &item.ClearedAt); err != nil {
			return nil, err
		}
		item.AmountSigned = round2(item.Debit - item.Credit)
		if item.AmountSigned >= 0 {
			item.OriginalSide = "debit"
		} else {
			item.OriginalSide = "credit"
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *GLService) CreateClearing(ctx context.Context, tenantID, userID uuid.UUID, req *glmodels.CreateClearingRequest) (*glmodels.ClearingResult, error) {
	if err := s.ensureClearingColumns(ctx); err != nil {
		return nil, err
	}
	if len(req.SelectedLineIDs) == 0 {
		return nil, fmt.Errorf("please select at least one open item")
	}
	if req.WithPosting && req.NewLine == nil {
		return nil, fmt.Errorf("new transaction line is required for posting + clearing mode")
	}
	if !req.WithPosting && req.NewLine != nil {
		req.NewLine = nil
	}
	var openItemManaged bool
	if err := s.db.QueryRow(ctx, `SELECT open_item_managed FROM gl_accounts WHERE id=$1 AND tenant_id=$2`, req.MasterAccountID, tenantID).Scan(&openItemManaged); err != nil {
		return nil, fmt.Errorf("load master clearing account: %w", err)
	}
	if !openItemManaged {
		return nil, fmt.Errorf("master clearing account is not open item managed")
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var orgID *uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT organization_id FROM gl_journal_entries e
		JOIN gl_journal_lines l ON l.entry_id=e.id
		WHERE l.id=$1 AND e.tenant_id=$2`, req.SelectedLineIDs[0], tenantID).Scan(&orgID); err != nil {
		return nil, fmt.Errorf("load organization from selected item: %w", err)
	}
	periodID, err := s.derivePeriod(ctx, tenantID, req.ClearingDate, uuidFromPtr(orgID))
	if err != nil {
		return nil, fmt.Errorf("derive period: %w", err)
	}
	if err := s.validatePeriod(ctx, tenantID, periodID); err != nil {
		return nil, err
	}

	selectedSigned, err := s.lockSelectedOpenItems(ctx, tx, tenantID, req.MasterAccountID, req.SelectedLineIDs)
	if err != nil {
		return nil, err
	}

	newMasterSigned := 0.0
	if req.WithPosting {
		newSigned := req.NewLine.Amount
		if strings.EqualFold(req.NewLine.Direction, "credit") {
			newSigned = -req.NewLine.Amount
		}
		newMasterSigned = -newSigned
	}
	diff := round2(selectedSigned + newMasterSigned)
	if math.Abs(diff) > clearingTolerance {
		return nil, fmt.Errorf("借贷不平衡，当前差额为 %.2f，无法执行清账", diff)
	}

	clearingID := uuid.New()
	docNo, err := nextClearingDocumentNoTx(ctx, tx, tenantID)
	if err != nil {
		return nil, err
	}
	description := strings.TrimSpace(req.Description)
	if description == "" {
		if req.WithPosting {
			description = "Open item posting and clearing"
		} else {
			description = "Open item clearing"
		}
	}
	if _, err := tx.Exec(ctx, `INSERT INTO gl_journal_entries
		(id, tenant_id, organization_id, document_no, posting_date, document_date, period_id,
		 description, reference, entry_type, status, source, created_by, created_at, posted_at, posted_by)
		VALUES ($1,$2,$3,$4,$5,$5,$6,$7,$8,'normal','posted','clearing',$9,NOW(),NOW(),$9)`,
		clearingID, tenantID, orgID, docNo, req.ClearingDate, periodID, description, docNo, userID); err != nil {
		return nil, fmt.Errorf("insert clearing journal header: %w", err)
	}

	if req.WithPosting {
		if err := s.insertPostingClearingLines(ctx, tx, tenantID, clearingID, periodID, req); err != nil {
			return nil, err
		}
	}

	tag, err := tx.Exec(ctx, `UPDATE gl_journal_lines
		SET open_item_status='cleared', clearing_doc_id=$1, clearing_date=$2, cleared_at=NOW()
		WHERE id = ANY($3) AND account_id=$4 AND COALESCE(open_item_status,'open')='open'`,
		clearingID, req.ClearingDate, req.SelectedLineIDs, req.MasterAccountID)
	if err != nil {
		return nil, fmt.Errorf("mark selected open items cleared: %w", err)
	}
	if int(tag.RowsAffected()) != len(req.SelectedLineIDs) {
		return nil, fmt.Errorf("some selected open items were already cleared by another user")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &glmodels.ClearingResult{
		ClearingEntryID: clearingID,
		ClearingDocNo:   docNo,
		ClearedCount:    len(req.SelectedLineIDs),
		Difference:      diff,
	}, nil
}

func (s *GLService) CancelClearing(ctx context.Context, tenantID, userID, clearingEntryID uuid.UUID) (*glmodels.CancelClearingResult, error) {
	if err := s.ensureClearingColumns(ctx); err != nil {
		return nil, err
	}
	entry, err := s.entryRepo.GetByID(ctx, clearingEntryID, tenantID)
	if err != nil {
		return nil, err
	}
	if entry == nil {
		return nil, ErrEntryNotFound
	}
	if entry.Source != "clearing" || entry.Status != "posted" {
		return nil, fmt.Errorf("only posted clearing documents can be cancelled")
	}

	var reversalID *uuid.UUID
	reversalDocNo := ""
	if len(entry.Lines) > 0 {
		reversal, err := s.ReverseJournalEntry(ctx, tenantID, userID, clearingEntryID, "negative")
		if err != nil {
			return nil, fmt.Errorf("reverse clearing journal: %w", err)
		}
		reversalID = &reversal.ID
		reversalDocNo = reversal.DocumentNo
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx, `UPDATE gl_journal_lines l
		SET open_item_status='open', clearing_doc_id=NULL, clearing_date=NULL, cleared_at=NULL
		FROM gl_journal_entries e
		WHERE l.entry_id=e.id AND e.tenant_id=$1
		  AND l.clearing_doc_id=$2 AND l.entry_id <> $2`, tenantID, clearingEntryID)
	if err != nil {
		return nil, fmt.Errorf("reopen cleared items: %w", err)
	}
	if _, err := tx.Exec(ctx, `UPDATE gl_journal_lines
		SET open_item_status='reversed', clearing_doc_id=NULL, clearing_date=NULL, cleared_at=NULL
		WHERE entry_id=$1 AND clearing_doc_id=$1`, clearingEntryID); err != nil {
		return nil, fmt.Errorf("mark clearing lines reversed: %w", err)
	}
	if _, err := tx.Exec(ctx, `UPDATE gl_journal_entries
		SET reference = COALESCE(NULLIF(reference,''), document_no) || ' / CANCELLED'
		WHERE id=$1 AND tenant_id=$2`, clearingEntryID, tenantID); err != nil {
		return nil, fmt.Errorf("mark clearing entry cancelled: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return &glmodels.CancelClearingResult{
		ClearingEntryID: clearingEntryID,
		ClearingDocNo:   entry.DocumentNo,
		ReversalEntryID: reversalID,
		ReversalDocNo:   reversalDocNo,
		ReopenedCount:   tag.RowsAffected(),
	}, nil
}

func (s *GLService) lockSelectedOpenItems(ctx context.Context, tx pgx.Tx, tenantID, accountID uuid.UUID, lineIDs []uuid.UUID) (float64, error) {
	rows, err := tx.Query(ctx, `SELECT l.id, l.debit::float8, l.credit::float8
		FROM gl_journal_lines l
		JOIN gl_journal_entries e ON e.id=l.entry_id
		JOIN gl_accounts a ON a.id=l.account_id
		WHERE e.tenant_id=$1 AND e.status='posted' AND l.account_id=$2
		  AND a.open_item_managed = true
		  AND l.id = ANY($3) AND COALESCE(l.open_item_status,'open')='open'
		FOR UPDATE OF l`, tenantID, accountID, lineIDs)
	if err != nil {
		return 0, fmt.Errorf("lock selected open items: %w", err)
	}
	defer rows.Close()
	found := map[uuid.UUID]bool{}
	total := 0.0
	for rows.Next() {
		var id uuid.UUID
		var debit, credit float64
		if err := rows.Scan(&id, &debit, &credit); err != nil {
			return 0, err
		}
		found[id] = true
		total += debit - credit
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}
	if len(found) != len(lineIDs) {
		return 0, fmt.Errorf("one or more selected items are not open for this account")
	}
	return round2(total), nil
}

func (s *GLService) insertPostingClearingLines(ctx context.Context, tx pgx.Tx, tenantID, entryID, periodID uuid.UUID, req *glmodels.CreateClearingRequest) error {
	nl := req.NewLine
	masterDebit, masterCredit := 0.0, 0.0
	offsetDebit, offsetCredit := 0.0, 0.0
	if strings.EqualFold(nl.Direction, "debit") {
		offsetDebit = nl.Amount
		masterCredit = nl.Amount
	} else {
		offsetCredit = nl.Amount
		masterDebit = nl.Amount
	}
	offsetLineID := uuid.New()
	masterLineID := uuid.New()
	if _, err := tx.Exec(ctx, `INSERT INTO gl_journal_lines
		(id, entry_id, account_id, account_code, account_name, debit, credit, description, cost_center_id, open_item_status)
		VALUES ($1,$2,$3,(SELECT account_code FROM gl_accounts WHERE id=$3),(SELECT account_name FROM gl_accounts WHERE id=$3),$4,$5,$6,$7,'not_managed')`,
		offsetLineID, entryID, nl.OffsettingAccountID, offsetDebit, offsetCredit, nl.Description, nl.CostCenterID); err != nil {
		return fmt.Errorf("insert clearing offset line: %w", err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO gl_journal_lines
		(id, entry_id, account_id, account_code, account_name, debit, credit, description, open_item_status, clearing_doc_id, clearing_date, cleared_at)
		VALUES ($1,$2,$3,(SELECT account_code FROM gl_accounts WHERE id=$3),(SELECT account_name FROM gl_accounts WHERE id=$3),$4,$5,$6,'cleared',$2,$7,NOW())`,
		masterLineID, entryID, req.MasterAccountID, masterDebit, masterCredit, "Generated clearing line", req.ClearingDate); err != nil {
		return fmt.Errorf("insert generated clearing line: %w", err)
	}
	if err := updateClearingBalanceTx(ctx, tx, tenantID, nl.OffsettingAccountID, periodID, offsetDebit, offsetCredit); err != nil {
		return err
	}
	return updateClearingBalanceTx(ctx, tx, tenantID, req.MasterAccountID, periodID, masterDebit, masterCredit)
}

func updateClearingBalanceTx(ctx context.Context, tx pgx.Tx, tenantID, accountID, periodID uuid.UUID, debit, credit float64) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO gl_account_balances (tenant_id, account_id, period_id, opening_balance, period_debit, period_credit, closing_balance, updated_at)
		SELECT $1, $2, $3,
		       COALESCE((SELECT ab.closing_balance
		                 FROM gl_account_balances ab
		                 JOIN gl_periods p ON p.id = ab.period_id
		                 WHERE ab.tenant_id = $1 AND ab.account_id = $2
		                   AND (p.fiscal_year < cur.fiscal_year OR
		                        (p.fiscal_year = cur.fiscal_year AND p.period_no < cur.period_no))
		                 ORDER BY p.fiscal_year DESC, p.period_no DESC
		                 LIMIT 1), 0),
		       COALESCE(ab2.period_debit, 0) + $4,
		       COALESCE(ab2.period_credit, 0) + $5,
		       COALESCE((SELECT ab.closing_balance
		                 FROM gl_account_balances ab
		                 JOIN gl_periods p ON p.id = ab.period_id
		                 WHERE ab.tenant_id = $1 AND ab.account_id = $2
		                   AND (p.fiscal_year < cur.fiscal_year OR
		                        (p.fiscal_year = cur.fiscal_year AND p.period_no < cur.period_no))
		                 ORDER BY p.fiscal_year DESC, p.period_no DESC
		                 LIMIT 1), 0) +
		       COALESCE(ab2.period_debit, 0) + $4 -
		       COALESCE(ab2.period_credit, 0) - $5,
		       NOW()
		FROM gl_periods cur
		LEFT JOIN gl_account_balances ab2 ON ab2.period_id = cur.id AND ab2.account_id = $2 AND ab2.tenant_id = $1
		WHERE cur.id = $3
		ON CONFLICT (tenant_id, account_id, period_id) DO UPDATE SET
		    period_debit  = gl_account_balances.period_debit + $4,
		    period_credit = gl_account_balances.period_credit + $5,
		    closing_balance = gl_account_balances.opening_balance +
		                      (gl_account_balances.period_debit + $4) -
		                      (gl_account_balances.period_credit + $5),
		    updated_at = NOW()
	`, tenantID, accountID, periodID, debit, credit)
	if err != nil {
		return fmt.Errorf("update clearing balance for account %s: %w", accountID, err)
	}
	return nil
}

func nextClearingDocumentNoTx(ctx context.Context, tx pgx.Tx, tenantID uuid.UUID) (string, error) {
	prefix := fmt.Sprintf("CL-%s-", time.Now().Format("200601"))
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

func uuidFromPtr(id *uuid.UUID) uuid.UUID {
	if id == nil {
		return uuid.Nil
	}
	return *id
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}
