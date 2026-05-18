package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	glmodels "github.com/swiftai-erp/backend/internal/gl/models"
)

// EntryRepo handles journal entry CRUD with validation.
type EntryRepo struct {
	db *pgxpool.Pool
}

func NewEntryRepo(db *pgxpool.Pool) *EntryRepo {
	return &EntryRepo{db: db}
}

// Create inserts a new journal entry with its lines in a transaction.
func (r *EntryRepo) Create(ctx context.Context, tenantID, userID uuid.UUID, req *glmodels.CreateJournalEntryRequest) (*glmodels.JournalEntry, error) {
	entry := &glmodels.JournalEntry{
		ID:             uuid.New(),
		TenantID:       tenantID,
		OrganizationID: req.OrganizationID,
		DocumentNo:     generateDocumentNo(ctx, r.db, tenantID),
		PostingDate:    req.PostingDate,
		DocumentDate:   req.DocumentDate,
		PeriodID:       req.PeriodID,
		Description:    req.Description,
		Reference:      req.Reference,
		EntryType:      req.EntryType,
		Status:         "draft",
		Source:         req.Source,
		CreatedBy:      userID,
		CreatedAt:      time.Now(),
	}

	if entry.EntryType == "" {
		entry.EntryType = "normal"
	}
	if entry.Source == "" {
		entry.Source = "manual"
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Insert header
	headerQuery := `
		INSERT INTO gl_journal_entries (id, tenant_id, organization_id, document_no,
		                                posting_date, document_date, period_id,
		                                description, reference, entry_type, status, source,
		                                created_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`
	_, err = tx.Exec(ctx, headerQuery,
		entry.ID, entry.TenantID, entry.OrganizationID, entry.DocumentNo,
		entry.PostingDate, entry.DocumentDate, entry.PeriodID,
		entry.Description, entry.Reference, entry.EntryType, entry.Status, entry.Source,
		entry.CreatedBy, entry.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("insert journal entry: %w", err)
	}

	// Insert lines
	for _, l := range req.Lines {
		lineID := uuid.New()
		_, err = tx.Exec(ctx, `
			INSERT INTO gl_journal_lines (id, entry_id, account_id, account_code, account_name,
			                              debit, credit, description, cost_center_id, partner_id, partner_type)
			VALUES ($1, $2, $3,
			        (SELECT account_code FROM gl_accounts WHERE id = $3),
			        (SELECT account_name FROM gl_accounts WHERE id = $3),
			        $4, $5, $6, $7, $8, $9)
		`, lineID, entry.ID, l.AccountID, l.Debit, l.Credit, l.Description,
			l.CostCenterID, l.PartnerID, l.PartnerType)
		if err != nil {
			return nil, fmt.Errorf("insert journal line: %w", err)
		}

		line := glmodels.JournalLine{
			ID:           lineID,
			EntryID:      entry.ID,
			AccountID:    l.AccountID,
			Debit:        l.Debit,
			Credit:       l.Credit,
			Description:  l.Description,
			CostCenterID: l.CostCenterID,
			PartnerID:    l.PartnerID,
			PartnerType:  l.PartnerType,
		}
		entry.Lines = append(entry.Lines, line)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit tx: %w", err)
	}

	return entry, nil
}

// GetByID retrieves a journal entry with its lines.
func (r *EntryRepo) GetByID(ctx context.Context, id, tenantID uuid.UUID) (*glmodels.JournalEntry, error) {
	query := `
		SELECT e.id, e.tenant_id, e.organization_id,
		       COALESCE(o.org_code || ' - ' || o.org_name, ''),
		       e.document_no, e.posting_date,
		       e.document_date, e.period_id,
		       e.description, e.reference, e.entry_type, e.status, e.source,
		       e.ai_confidence, e.created_by, e.created_at, e.posted_at, e.posted_by
		FROM gl_journal_entries e
		LEFT JOIN organizations o ON o.id = e.organization_id
		WHERE e.id = $1 AND e.tenant_id = $2
	`
	entry := &glmodels.JournalEntry{}
	err := r.db.QueryRow(ctx, query, id, tenantID).Scan(
		&entry.ID, &entry.TenantID, &entry.OrganizationID, &entry.OrganizationName, &entry.DocumentNo, &entry.PostingDate,
		&entry.DocumentDate, &entry.PeriodID,
		&entry.Description, &entry.Reference, &entry.EntryType, &entry.Status, &entry.Source,
		&entry.AIConfidence, &entry.CreatedBy, &entry.CreatedAt, &entry.PostedAt, &entry.PostedBy,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get journal entry: %w", err)
	}

	// Load lines
	lines, err := r.getLines(ctx, entry.ID)
	if err != nil {
		return nil, err
	}
	entry.Lines = lines

	return entry, nil
}

// ListByTenant retrieves journal entries for a tenant, newest first.
func (r *EntryRepo) ListByTenant(ctx context.Context, tenantID uuid.UUID, limit, offset int) ([]*glmodels.JournalEntry, int64, error) {
	// Count
	var total int64
	err := r.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM gl_journal_entries WHERE tenant_id = $1", tenantID,
	).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("count entries: %w", err)
	}

	if limit <= 0 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, tenant_id, organization_id, document_no, posting_date,
		       document_date, period_id,
		       description, reference, entry_type, status, source,
		       ai_confidence, created_by, created_at, posted_at, posted_by
		FROM gl_journal_entries WHERE tenant_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, query, tenantID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("list entries: %w", err)
	}
	defer rows.Close()

	var entries []*glmodels.JournalEntry
	for rows.Next() {
		entry := &glmodels.JournalEntry{}
		err := rows.Scan(
			&entry.ID, &entry.TenantID, &entry.OrganizationID, &entry.OrganizationName, &entry.DocumentNo, &entry.PostingDate,
			&entry.DocumentDate, &entry.PeriodID,
			&entry.Description, &entry.Reference, &entry.EntryType, &entry.Status, &entry.Source,
			&entry.AIConfidence, &entry.CreatedBy, &entry.CreatedAt, &entry.PostedAt, &entry.PostedBy,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scan entry: %w", err)
		}
		entries = append(entries, entry)
	}

	// Load lines for each entry and compute totals
	for _, e := range entries {
		lines, err := r.getLines(ctx, e.ID)
		if err != nil {
			return nil, 0, fmt.Errorf("get lines for entry %s: %w", e.ID, err)
		}
		e.Lines = lines
		for _, l := range lines {
			e.TotalDebit += l.Debit
			e.TotalCredit += l.Credit
		}
	}

	return entries, total, nil
}

// UpdateStatus updates the status of a journal entry.
func (r *EntryRepo) UpdateStatus(ctx context.Context, entryID, tenantID uuid.UUID, status string, postedBy *uuid.UUID) error {
	now := time.Now()
	var err error
	if status == "posted" && postedBy != nil {
		_, err = r.db.Exec(ctx,
			`UPDATE gl_journal_entries SET status = $1, posted_at = $2, posted_by = $3
			 WHERE id = $4 AND tenant_id = $5`,
			status, now, *postedBy, entryID, tenantID)
	} else {
		_, err = r.db.Exec(ctx,
			`UPDATE gl_journal_entries SET status = $1 WHERE id = $2 AND tenant_id = $3`,
			status, entryID, tenantID)
	}
	if err != nil {
		return fmt.Errorf("update entry status: %w", err)
	}
	return nil
}

// ListFiltered retrieves entries with optional status and entry_type filters.
func (r *EntryRepo) ListFiltered(ctx context.Context, tenantID uuid.UUID, limit, offset int, status, entryType string) ([]*glmodels.JournalEntry, int64, error) {
	// Build dynamic WHERE clause
	whereClause := "WHERE e.tenant_id = $1"
	args := []interface{}{tenantID}
	argIdx := 2

	if status != "" {
		whereClause += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	if entryType != "" {
		whereClause += fmt.Sprintf(" AND entry_type = $%d", argIdx)
		args = append(args, entryType)
		argIdx++
	}

	// Count
	var total int64
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM gl_journal_entries e %s", whereClause)
	err := r.db.QueryRow(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("count entries: %w", err)
	}

	if limit <= 0 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	query := fmt.Sprintf(`
		SELECT e.id, e.tenant_id, e.organization_id,
		       COALESCE(o.org_code || ' - ' || o.org_name, ''),
		       e.document_no, e.posting_date,
		       e.document_date, e.period_id,
		       e.description, e.reference, e.entry_type, e.status, e.source,
		       e.ai_confidence, e.created_by, e.created_at, e.posted_at, e.posted_by
		FROM gl_journal_entries e
		LEFT JOIN organizations o ON o.id = e.organization_id
		%s
		ORDER BY e.created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIdx, argIdx+1)

	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list entries: %w", err)
	}
	defer rows.Close()

	var entries []*glmodels.JournalEntry
	for rows.Next() {
		entry := &glmodels.JournalEntry{}
		err := rows.Scan(
			&entry.ID, &entry.TenantID, &entry.OrganizationID, &entry.OrganizationName, &entry.DocumentNo, &entry.PostingDate,
			&entry.DocumentDate, &entry.PeriodID,
			&entry.Description, &entry.Reference, &entry.EntryType, &entry.Status, &entry.Source,
			&entry.AIConfidence, &entry.CreatedBy, &entry.CreatedAt, &entry.PostedAt, &entry.PostedBy,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scan entry: %w", err)
		}
		entries = append(entries, entry)
	}

	// Load lines and compute totals for each entry
	for _, e := range entries {
		lines, err := r.getLines(ctx, e.ID)
		if err != nil {
			return nil, 0, fmt.Errorf("get lines for entry %s: %w", e.ID, err)
		}
		e.Lines = lines
		for _, l := range lines {
			e.TotalDebit += l.Debit
			e.TotalCredit += l.Credit
		}
	}

	return entries, total, nil
}

// ListByStatus retrieves entries filtered by status.
func (r *EntryRepo) ListByStatus(ctx context.Context, tenantID uuid.UUID, status string) ([]*glmodels.JournalEntry, error) {
	query := `
		SELECT id, tenant_id, organization_id, document_no, posting_date,
		       document_date, period_id,
		       description, reference, entry_type, status, source,
		       ai_confidence, created_by, created_at, posted_at, posted_by
		FROM gl_journal_entries WHERE tenant_id = $1 AND status = $2
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(ctx, query, tenantID, status)
	if err != nil {
		return nil, fmt.Errorf("list entries by status: %w", err)
	}
	defer rows.Close()

	var entries []*glmodels.JournalEntry
	for rows.Next() {
		entry := &glmodels.JournalEntry{}
		err := rows.Scan(
			&entry.ID, &entry.TenantID, &entry.OrganizationID, &entry.OrganizationName, &entry.DocumentNo, &entry.PostingDate,
			&entry.DocumentDate, &entry.PeriodID,
			&entry.Description, &entry.Reference, &entry.EntryType, &entry.Status, &entry.Source,
			&entry.AIConfidence, &entry.CreatedBy, &entry.CreatedAt, &entry.PostedAt, &entry.PostedBy,
		)
		if err != nil {
			return nil, fmt.Errorf("scan entry: %w", err)
		}
		entries = append(entries, entry)
	}

	for _, e := range entries {
		lines, err := r.getLines(ctx, e.ID)
		if err != nil {
			return nil, fmt.Errorf("get lines for entry %s: %w", e.ID, err)
		}
		e.Lines = lines
	}

	return entries, nil
}

func (r *EntryRepo) getLines(ctx context.Context, entryID uuid.UUID) ([]glmodels.JournalLine, error) {
	query := `
		SELECT id, entry_id, account_id, account_code, account_name,
		       debit, credit, description, cost_center_id, partner_id, partner_type
		FROM gl_journal_lines WHERE entry_id = $1
		ORDER BY id
	`
	rows, err := r.db.Query(ctx, query, entryID)
	if err != nil {
		return nil, fmt.Errorf("get lines: %w", err)
	}
	defer rows.Close()

	var lines []glmodels.JournalLine
	for rows.Next() {
		var l glmodels.JournalLine
		err := rows.Scan(
			&l.ID, &l.EntryID, &l.AccountID, &l.AccountCode, &l.AccountName,
			&l.Debit, &l.Credit, &l.Description, &l.CostCenterID, &l.PartnerID, &l.PartnerType,
		)
		if err != nil {
			return nil, fmt.Errorf("scan line: %w", err)
		}
		lines = append(lines, l)
	}
	return lines, nil
}

// ── Attachments ──

// AddAttachment saves an attachment record for a journal entry.
func (r *EntryRepo) AddAttachment(ctx context.Context, att *glmodels.EntryAttachment) error {
	query := `
		INSERT INTO gl_entry_attachments (id, entry_id, file_name, file_type, file_size, file_path, description, uploaded_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	_, err := r.db.Exec(ctx, query,
		att.ID, att.EntryID, att.FileName, att.FileType, att.FileSize,
		att.FilePath, att.Description, att.UploadedBy, att.CreatedAt,
	)
	if err != nil {
		return fmt.Errorf("add attachment: %w", err)
	}
	return nil
}

// GetAccountLedger returns journal lines for a specific account within a date range.
func (r *EntryRepo) GetAccountLedger(ctx context.Context, tenantID, accountID uuid.UUID, fromDate, toDate time.Time, page, pageSize int) ([]*glmodels.JournalLine, int64, error) {
	// Count
	var total int64
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM gl_journal_lines l
		INNER JOIN gl_journal_entries e ON e.id = l.entry_id
		WHERE e.tenant_id = $1 AND l.account_id = $2
		  AND e.posting_date >= $3 AND e.posting_date <= $4
	`, tenantID, accountID, fromDate, toDate).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("count ledger: %w", err)
	}

	offset := (page - 1) * pageSize
	query := `
		SELECT l.id, l.entry_id, l.account_id, l.account_code, l.account_name,
		       l.debit, l.credit, COALESCE(l.description,'') as description,
		       l.cost_center_id, l.partner_id, COALESCE(l.partner_type,'') as partner_type
		FROM gl_journal_lines l
		INNER JOIN gl_journal_entries e ON e.id = l.entry_id
		WHERE e.tenant_id = $1 AND l.account_id = $2
		  AND e.posting_date >= $3 AND e.posting_date <= $4
		ORDER BY e.posting_date, e.document_no
		LIMIT $5 OFFSET $6
	`
	rows, err := r.db.Query(ctx, query, tenantID, accountID, fromDate, toDate, pageSize, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("query ledger: %w", err)
	}
	defer rows.Close()

	var lines []*glmodels.JournalLine
	for rows.Next() {
		l := &glmodels.JournalLine{}
		err := rows.Scan(
			&l.ID, &l.EntryID, &l.AccountID, &l.AccountCode, &l.AccountName,
			&l.Debit, &l.Credit, &l.Description, &l.CostCenterID, &l.PartnerID, &l.PartnerType,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scan ledger line: %w", err)
		}
		lines = append(lines, l)
	}
	return lines, total, nil
}

// GetAccountBalances returns period-wise debit/credit totals for leaf accounts only.
func (r *EntryRepo) GetAccountBalances(ctx context.Context, tenantID uuid.UUID, year, month int) ([]map[string]interface{}, error) {
	query := `
		SELECT a.id, a.account_code, a.account_name, a.account_type, a.level,
		       COALESCE(SUM(filtered.debit), 0) as total_debit,
		       COALESCE(SUM(filtered.credit), 0) as total_credit
		FROM gl_accounts a
		LEFT JOIN (
		  SELECT l.account_id, l.debit, l.credit
		  FROM gl_journal_lines l
		  INNER JOIN gl_journal_entries e ON e.id = l.entry_id AND e.status = 'posted'
		  WHERE e.tenant_id = $1
		    AND EXTRACT(YEAR FROM e.posting_date) = $2
		    AND ($3 = 0 OR EXTRACT(MONTH FROM e.posting_date) = $3)
		) filtered ON filtered.account_id = a.id
		WHERE a.tenant_id = $1 AND a.is_leaf = true
		GROUP BY a.id, a.account_code, a.account_name, a.account_type, a.level
		ORDER BY a.account_code
	`
	rows, err := r.db.Query(ctx, query, tenantID, year, month)
	if err != nil {
		return nil, fmt.Errorf("query balances: %w", err)
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, code, name, at string
		var level int
		var debit, credit float64
		err := rows.Scan(&id, &code, &name, &at, &level, &debit, &credit)
		if err != nil {
			return nil, fmt.Errorf("scan balance: %w", err)
		}
		lowerAt := strings.ToLower(at)
		balance := debit - credit
		if lowerAt == "liability" || lowerAt == "equity" || lowerAt == "revenue" || lowerAt == "other_income" {
			balance = credit - debit
		}
		results = append(results, map[string]interface{}{
			"account_id":     id,
			"account_code":   code,
			"account_name":   name,
			"account_type":   at,
			"level":          level,
			"is_leaf":        true,
			"total_debit":    debit,
			"total_credit":   credit,
			"balance":        balance,
		})
	}
	return results, nil
}

// ── Financial Reports ──

// GetBalanceSheet returns assets, liabilities, and equity with calculated retained earnings.
func (r *EntryRepo) GetBalanceSheet(ctx context.Context, tenantID uuid.UUID, year, month int) (map[string]interface{}, error) {
	// Get all accounts with their period balances
	balances, err := r.GetAccountBalances(ctx, tenantID, year, month)
	if err != nil {
		return nil, err
	}

	// Get cumulative P&L for the period (net income)
	netIncome, err := r.GetNetIncome(ctx, tenantID, year, month)
	if err != nil {
		return nil, err
	}

	var assets, liabilities, equity []map[string]interface{}
	var totalAssets, totalLiabilities, totalEquity float64
	var retainedEarningsAccount map[string]interface{}

	for _, b := range balances {
		at := strings.ToLower(b["account_type"].(string))
		bal := b["balance"].(float64)

		// Skip zero-balance accounts
		if bal == 0 {
			continue
		}

		entry := map[string]interface{}{
			"account_code": b["account_code"],
			"account_name": b["account_name"],
			"balance":      bal,
		}

		switch at {
		case "asset":
			assets = append(assets, entry)
			totalAssets += bal
		case "liability":
			liabilities = append(liabilities, entry)
			totalLiabilities += bal
		case "equity":
			// Check if this is a retained earnings account
			name := b["account_name"].(string)
			code := b["account_code"].(string)
			if containsRetainedEarnings(name, code) {
				retainedEarningsAccount = entry
			} else {
				equity = append(equity, entry)
				totalEquity += bal
			}
		}
	}

	// Calculate retained earnings: equity opening balance + current net income
	// If we found a RE account, add net income to its balance
	retainedEarnings := netIncome
	if retainedEarningsAccount != nil {
		retainedEarnings += retainedEarningsAccount["balance"].(float64)
	}

	retainedEntry := map[string]interface{}{
		"account_code": "RE",
		"account_name": "Retained Earnings",
		"balance":      retainedEarnings,
		"from_pnl":     netIncome,
	}
	equity = append(equity, retainedEntry)
	totalEquity += retainedEarnings

	result := map[string]interface{}{
		"assets":           assets,
		"liabilities":      liabilities,
		"equity":           equity,
		"total_assets":     totalAssets,
		"total_liabilities": totalLiabilities,
		"total_equity":     totalEquity,
		"net_income":       netIncome,
		"year":             year,
		"month":            month,
	}

	return result, nil
}

// GetProfitLoss returns revenue and expense accounts with totals and net income.
func (r *EntryRepo) GetProfitLoss(ctx context.Context, tenantID uuid.UUID, year, month int) (map[string]interface{}, error) {
	balances, err := r.GetAccountBalances(ctx, tenantID, year, month)
	if err != nil {
		return nil, err
	}

	var revenues, expenses []map[string]interface{}
	var totalRevenue, totalExpense float64

	for _, b := range balances {
		at := strings.ToLower(b["account_type"].(string))
		bal := b["balance"].(float64)

		// Skip zero-balance accounts
		if bal == 0 {
			continue
		}

		entry := map[string]interface{}{
			"account_code": b["account_code"],
			"account_name": b["account_name"],
			"balance":      bal,
		}

		switch at {
		case "revenue", "other_income":
			revenues = append(revenues, entry)
			totalRevenue += bal
		case "expense", "cogs", "other_expense":
			expenses = append(expenses, entry)
			totalExpense += bal
		}
	}

	netIncome := totalRevenue - totalExpense

	result := map[string]interface{}{
		"revenues":       revenues,
		"expenses":       expenses,
		"total_revenue":  totalRevenue,
		"total_expense":  totalExpense,
		"net_income":     netIncome,
		"year":           year,
		"month":          month,
	}

	return result, nil
}

// GetNetIncome calculates net income for a period (revenue - expenses).
func (r *EntryRepo) GetNetIncome(ctx context.Context, tenantID uuid.UUID, year, month int) (float64, error) {
	query := `
		SELECT
		  COALESCE(SUM(CASE WHEN LOWER(a.account_type) IN ('revenue','other_income') THEN l.credit - l.debit ELSE 0 END), 0) -
		  COALESCE(SUM(CASE WHEN LOWER(a.account_type) IN ('expense','cogs','other_expense') THEN l.debit - l.credit ELSE 0 END), 0)
		FROM gl_journal_lines l
		INNER JOIN gl_journal_entries e ON e.id = l.entry_id AND e.status = 'posted'
		INNER JOIN gl_accounts a ON a.id = l.account_id
		WHERE e.tenant_id = $1
		  AND EXTRACT(YEAR FROM e.posting_date) = $2
		  AND ($3 = 0 OR EXTRACT(MONTH FROM e.posting_date) = $3)
	`
	var netIncome float64
	err := r.db.QueryRow(ctx, query, tenantID, year, month).Scan(&netIncome)
	if err != nil {
		return 0, fmt.Errorf("calculate net income: %w", err)
	}
	return netIncome, nil
}

func containsRetainedEarnings(name, code string) bool {
	keywords := []string{"retained", "earning", "accumulated", "profit", "loss"}
	lower := strings.ToLower(name + " " + code)
	for _, kw := range keywords {
		if strings.Contains(lower, kw) {
			return true
		}
	}
	return false
}

// GetAttachments retrieves all attachments for a journal entry.
func (r *EntryRepo) GetAttachments(ctx context.Context, entryID uuid.UUID) ([]glmodels.EntryAttachment, error) {
	query := `
		SELECT id, entry_id, file_name, file_type, file_size, file_path,
		       COALESCE(description,'') as description, uploaded_by, created_at
		FROM gl_entry_attachments WHERE entry_id = $1 ORDER BY created_at
	`
	rows, err := r.db.Query(ctx, query, entryID)
	if err != nil {
		return nil, fmt.Errorf("get attachments: %w", err)
	}
	defer rows.Close()

	var atts []glmodels.EntryAttachment
	for rows.Next() {
		var a glmodels.EntryAttachment
		err := rows.Scan(&a.ID, &a.EntryID, &a.FileName, &a.FileType, &a.FileSize, &a.FilePath,
			&a.Description, &a.UploadedBy, &a.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("scan attachment: %w", err)
		}
		atts = append(atts, a)
	}
	return atts, nil
}

// DeleteEntry deletes a draft journal entry and its lines and attachments.
func (r *EntryRepo) DeleteEntry(ctx context.Context, entryID, tenantID uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Delete lines
	_, err = tx.Exec(ctx, `DELETE FROM gl_journal_lines WHERE entry_id = $1`, entryID)
	if err != nil {
		return fmt.Errorf("delete lines: %w", err)
	}

	// Delete attachments
	_, err = tx.Exec(ctx, `DELETE FROM gl_entry_attachments WHERE entry_id = $1`, entryID)
	if err != nil {
		return fmt.Errorf("delete attachments: %w", err)
	}

	// Delete entry
	result, err := tx.Exec(ctx, `DELETE FROM gl_journal_entries WHERE id = $1 AND tenant_id = $2`, entryID, tenantID)
	if err != nil {
		return fmt.Errorf("delete entry: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("entry not found")
	}

	return tx.Commit(ctx)
}

// DeleteAttachment removes an attachment by ID.
// GetAttachmentByID retrieves a single attachment by ID and entry ID.
func (r *EntryRepo) GetAttachmentByID(ctx context.Context, id, entryID uuid.UUID) (*glmodels.EntryAttachment, error) {
	query := `
		SELECT id, entry_id, file_name, file_type, file_size, file_path,
		       COALESCE(description,'') as description, uploaded_by, created_at
		FROM gl_entry_attachments WHERE id = $1 AND entry_id = $2
	`
	var a glmodels.EntryAttachment
	err := r.db.QueryRow(ctx, query, id, entryID).Scan(
		&a.ID, &a.EntryID, &a.FileName, &a.FileType, &a.FileSize, &a.FilePath,
		&a.Description, &a.UploadedBy, &a.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get attachment: %w", err)
	}
	return &a, nil
}

func (r *EntryRepo) DeleteAttachment(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, "DELETE FROM gl_entry_attachments WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("delete attachment: %w", err)
	}
	return nil
}

// UpdateDraftEntry updates header fields and replaces lines for a draft entry.
func (r *EntryRepo) UpdateDraftEntry(ctx context.Context, tenantID uuid.UUID, req *glmodels.CreateJournalEntryRequest, entryID uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Update header
	_, err = tx.Exec(ctx, `
		UPDATE gl_journal_entries
		SET posting_date = $1, document_date = $2, description = $3,
		    reference = $4, entry_type = $5, organization_id = $6
		WHERE id = $7 AND tenant_id = $8 AND status = 'draft'
	`, req.PostingDate, req.DocumentDate, req.Description,
		req.Reference, req.EntryType, req.OrganizationID, entryID, tenantID)
	if err != nil {
		return fmt.Errorf("update header: %w", err)
	}

	// Delete existing lines
	_, err = tx.Exec(ctx, `DELETE FROM gl_journal_lines WHERE entry_id = $1`, entryID)
	if err != nil {
		return fmt.Errorf("delete old lines: %w", err)
	}

	// Insert new lines
	for _, l := range req.Lines {
		_, err = tx.Exec(ctx, `
			INSERT INTO gl_journal_lines (id, entry_id, account_id, account_code, account_name,
			                              debit, credit, description, cost_center_id, partner_id, partner_type)
			VALUES ($1, $2, $3,
			        (SELECT account_code FROM gl_accounts WHERE id = $3),
			        (SELECT account_name FROM gl_accounts WHERE id = $3),
			        $4, $5, $6, $7, $8, $9)
		`, uuid.New(), entryID, l.AccountID, l.Debit, l.Credit, l.Description,
			l.CostCenterID, l.PartnerID, l.PartnerType)
		if err != nil {
			return fmt.Errorf("insert line: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// PostEntry updates status to 'posted' and updates gl_account_balances in a single transaction.
func (r *EntryRepo) PostEntry(ctx context.Context, entryID, tenantID, userID uuid.UUID) error {
	// Get entry with lines first (outside transaction to keep it short)
	entry, err := r.GetByID(ctx, entryID, tenantID)
	if err != nil || entry == nil {
		return fmt.Errorf("entry not found: %w", err)
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Update status
	now := time.Now()
	result, err := tx.Exec(ctx, `
		UPDATE gl_journal_entries
		SET status = 'posted', posted_at = $1, posted_by = $2
		WHERE id = $3 AND tenant_id = $4 AND status = 'draft'
	`, now, userID, entryID, tenantID)
	if err != nil {
		return fmt.Errorf("update status: %w", err)
	}
	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("entry not found or already posted")
	}

	// Update gl_account_balances for each line
	for _, line := range entry.Lines {
		// Use fiscal year/period for ordering (not UUID)
		_, err = tx.Exec(ctx, `
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
		`, tenantID, line.AccountID, entry.PeriodID, line.Debit, line.Credit)
		if err != nil {
			return fmt.Errorf("update balance for account %s: %w", line.AccountID, err)
		}
	}

	return tx.Commit(ctx)
}

// generateDocumentNo creates a sequential document number: GL-YYYYMM-XXXX

// generateDocumentNo creates a sequential document number: GL-YYYYMM-XXXX
// UnpostEntry reverses the effect of posting: subtracts from gl_account_balances and sets status to draft.
func (r *EntryRepo) UnpostEntry(ctx context.Context, entryID, tenantID uuid.UUID) error {
	entry, err := r.GetByID(ctx, entryID, tenantID)
	if err != nil || entry == nil {
		return fmt.Errorf("entry not found: %w", err)
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	result, err := tx.Exec(ctx, `
		UPDATE gl_journal_entries
		SET status = 'draft', posted_at = NULL, posted_by = NULL
		WHERE id = $1 AND tenant_id = $2 AND status = 'posted'
	`, entryID, tenantID)
	if err != nil {
		return fmt.Errorf("update status: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("entry not found or not posted")
	}

	for _, line := range entry.Lines {
		_, err = tx.Exec(ctx, `
			UPDATE gl_account_balances
			SET period_debit  = GREATEST(period_debit - $4, 0),
			    period_credit = GREATEST(period_credit - $5, 0),
			    closing_balance = opening_balance +
			                      GREATEST(period_debit - $4, 0) -
			                      GREATEST(period_credit - $5, 0),
			    updated_at = NOW()
			WHERE tenant_id = $1 AND account_id = $2 AND period_id = $3
		`, tenantID, line.AccountID, entry.PeriodID, line.Debit, line.Credit)
		if err != nil {
			return fmt.Errorf("reverse balance for account %s: %w", line.AccountID, err)
		}
	}

	return tx.Commit(ctx)
}
func generateDocumentNo(ctx context.Context, db *pgxpool.Pool, tenantID uuid.UUID) string {
	now := time.Now()
	prefix := fmt.Sprintf("GL-%s-", now.Format("200601"))

	var seq int
	err := db.QueryRow(ctx, `
		INSERT INTO gl_document_seq (tenant_id, prefix, seq)
		VALUES ($1, $2, 1)
		ON CONFLICT (tenant_id, prefix) DO UPDATE SET seq = gl_document_seq.seq + 1
		RETURNING gl_document_seq.seq
	`, tenantID, prefix).Scan(&seq)
	if err != nil {
		// Fallback: use timestamp-based number
		return fmt.Sprintf("%s%04d", prefix, now.UnixMilli()%10000)
	}

	return fmt.Sprintf("%s%04d", prefix, seq)
}
