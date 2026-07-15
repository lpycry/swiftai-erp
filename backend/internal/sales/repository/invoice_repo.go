package repository

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	salesmodels "github.com/swiftai-erp/backend/internal/sales/models"
)

func (r *SalesRepo) ensureInvoiceTables(ctx context.Context) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS sales_invoices (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			invoice_no VARCHAR(30) NOT NULL,
			delivery_id UUID NOT NULL REFERENCES sales_delivery_notes(id),
			sales_order_id UUID NOT NULL REFERENCES sales_orders(id),
			customer_id UUID NOT NULL REFERENCES customers(id),
			invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
			currency VARCHAR(10) NOT NULL DEFAULT 'USD',
			net_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			tax_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			total_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
			journal_entry_id UUID REFERENCES gl_journal_entries(id),
			created_by UUID REFERENCES users(id),
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			posted_at TIMESTAMPTZ,
			UNIQUE(tenant_id, invoice_no),
			UNIQUE(tenant_id, delivery_id)
		)`,
		`ALTER TABLE sales_invoices DROP CONSTRAINT IF EXISTS sales_invoices_tenant_id_delivery_id_key`,
		`CREATE TABLE IF NOT EXISTS sales_invoice_items (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			invoice_id UUID NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
			delivery_item_id UUID NOT NULL REFERENCES sales_delivery_note_items(id),
			so_item_id UUID NOT NULL REFERENCES sales_order_items(id),
			item_no INT NOT NULL,
			product_id UUID NOT NULL REFERENCES products(id),
			quantity NUMERIC(18,4) NOT NULL DEFAULT 0,
			unit_of_measure VARCHAR(20) DEFAULT 'EA',
			unit_price NUMERIC(18,4) NOT NULL DEFAULT 0,
			discount_pct NUMERIC(8,4) NOT NULL DEFAULT 0,
			net_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			tax_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			line_total NUMERIC(18,2) NOT NULL DEFAULT 0,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS invoice_tax_details (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			invoice_id UUID NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
			invoice_item_id UUID REFERENCES sales_invoice_items(id) ON DELETE CASCADE,
			tax_code VARCHAR(40) NOT NULL DEFAULT 'TAX_OUTPUT',
			jurisdiction VARCHAR(120) NOT NULL DEFAULT '',
			tax_rate NUMERIC(10,6) NOT NULL DEFAULT 0,
			taxable_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			tax_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`,
		`CREATE TABLE IF NOT EXISTS delivery_billing_status (
			tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
			delivery_id UUID NOT NULL REFERENCES sales_delivery_notes(id) ON DELETE CASCADE,
			delivery_item_id UUID NOT NULL REFERENCES sales_delivery_note_items(id) ON DELETE CASCADE,
			pgi_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			billed_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
			status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
			updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			PRIMARY KEY (tenant_id, delivery_item_id)
		)`,
	}
	for _, stmt := range stmts {
		if _, err := r.db.Exec(ctx, stmt); err != nil {
			return err
		}
	}
	return nil
}

func (r *SalesRepo) nextSalesInvoiceNo(ctx context.Context, tenantID uuid.UUID, invoiceDate time.Time) string {
	prefix := "INV" + invoiceDate.Format("20060102")
	var seq int
	_ = r.db.QueryRow(ctx, `SELECT COALESCE(MAX(SUBSTRING(invoice_no FROM '.{4}$')::int),0)+1
		FROM sales_invoices WHERE tenant_id=$1 AND invoice_no LIKE $2`, tenantID, prefix+"%").Scan(&seq)
	if seq < 1 {
		seq = 1
	}
	return fmt.Sprintf("%s%04d", prefix, seq)
}

func (r *SalesRepo) ListPendingInvoiceDeliveries(ctx context.Context, tenantID uuid.UUID) ([]*salesmodels.DeliveryNote, error) {
	if err := r.ensureDeliveryTables(ctx); err != nil {
		return nil, err
	}
	if err := r.ensureInvoiceTables(ctx); err != nil {
		return nil, err
	}
	rows, err := r.db.Query(ctx, `SELECT dn.id
		FROM sales_delivery_notes dn
		WHERE dn.tenant_id=$1 AND dn.status='PGI_POSTED'
		  AND EXISTS (
			SELECT 1
			FROM sales_delivery_note_items dni
			LEFT JOIN (
				SELECT sii.delivery_item_id, SUM(sii.quantity) AS billed_qty
				FROM sales_invoice_items sii
				JOIN sales_invoices si ON si.id=sii.invoice_id
				WHERE si.tenant_id=$1 AND si.status <> 'CANCELLED'
				GROUP BY sii.delivery_item_id
			) billed ON billed.delivery_item_id=dni.id
			WHERE dni.delivery_id=dn.id
			  AND dni.delivery_qty > COALESCE(billed.billed_qty,0)
		  )
		ORDER BY dn.pgi_at DESC NULLS LAST, dn.created_at DESC`, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.DeliveryNote
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		dn, err := r.GetDeliveryNote(ctx, id, tenantID)
		if err != nil {
			return nil, err
		}
		list = append(list, dn)
	}
	return list, rows.Err()
}

func (r *SalesRepo) CreateSalesInvoice(ctx context.Context, tenantID, userID uuid.UUID, req *salesmodels.CreateSalesInvoiceRequest) (*salesmodels.SalesInvoice, error) {
	if err := r.ensureDeliveryTables(ctx); err != nil {
		return nil, err
	}
	if err := r.ensureInvoiceTables(ctx); err != nil {
		return nil, err
	}
	deliveryID, err := uuid.Parse(req.DeliveryID)
	if err != nil {
		return nil, fmt.Errorf("invalid delivery_id")
	}
	invoiceDate := time.Now()
	if req.InvoiceDate != "" {
		parsed, err := time.Parse("2006-01-02", req.InvoiceDate)
		if err != nil {
			return nil, fmt.Errorf("invalid invoice_date: %w", err)
		}
		invoiceDate = parsed
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var status, currency string
	var soID, customerID, warehouseID uuid.UUID
	var soNet, soTax float64
	if err := tx.QueryRow(ctx, `SELECT dn.status, dn.sales_order_id, dn.customer_id, dn.warehouse_id,
			COALESCE(so.currency,'USD'), COALESCE(so.net_amount,0)::float8, COALESCE(so.tax_amount,0)::float8
		FROM sales_delivery_notes dn
		JOIN sales_orders so ON so.id=dn.sales_order_id
		WHERE dn.id=$1 AND dn.tenant_id=$2
		FOR UPDATE OF dn`, deliveryID, tenantID).Scan(&status, &soID, &customerID, &warehouseID, &currency, &soNet, &soTax); err != nil {
		return nil, fmt.Errorf("load delivery for invoice: %w", err)
	}
	if status != "PGI_POSTED" {
		return nil, fmt.Errorf("delivery must be PGI_POSTED before billing")
	}

	requested := map[uuid.UUID]float64{}
	hasExplicitItems := len(req.Items) > 0
	for _, reqItem := range req.Items {
		itemID, err := uuid.Parse(reqItem.DeliveryItemID)
		if err != nil {
			return nil, fmt.Errorf("invalid delivery_item_id")
		}
		if reqItem.BillingQty <= 0 {
			return nil, fmt.Errorf("billing qty must be greater than zero")
		}
		requested[itemID] += reqItem.BillingQty
	}

	rows, err := tx.Query(ctx, `SELECT dni.id, dni.so_item_id, dni.item_no, dni.product_id,
			dni.delivery_qty::float8, COALESCE(billed.billed_qty,0)::float8,
			GREATEST(dni.delivery_qty - COALESCE(billed.billed_qty,0),0)::float8,
			COALESCE(dni.unit_of_measure,'EA'),
			COALESCE(soi.unit_price,0)::float8, COALESCE(soi.discount_pct,0)::float8
		FROM sales_delivery_note_items dni
		JOIN sales_order_items soi ON soi.id=dni.so_item_id
		LEFT JOIN (
			SELECT sii.delivery_item_id, SUM(sii.quantity) AS billed_qty
			FROM sales_invoice_items sii
			JOIN sales_invoices si ON si.id=sii.invoice_id
			WHERE si.tenant_id=$2 AND si.status <> 'CANCELLED'
			GROUP BY sii.delivery_item_id
		) billed ON billed.delivery_item_id=dni.id
		WHERE dni.delivery_id=$1
		ORDER BY dni.item_no
		FOR UPDATE OF dni`, deliveryID, tenantID)
	if err != nil {
		return nil, err
	}
	type invLine struct {
		deliveryItemID uuid.UUID
		soItemID       uuid.UUID
		itemNo         int
		productID      uuid.UUID
		qty            float64
		deliveryQty    float64
		billedQty      float64
		openQty        float64
		uom            string
		unitPrice      float64
		discountPct    float64
		net            float64
		tax            float64
		total          float64
	}
	var lines []invLine
	netTotal := 0.0
	for rows.Next() {
		var line invLine
		if err := rows.Scan(&line.deliveryItemID, &line.soItemID, &line.itemNo, &line.productID, &line.deliveryQty, &line.billedQty, &line.openQty, &line.uom, &line.unitPrice, &line.discountPct); err != nil {
			rows.Close()
			return nil, err
		}
		if hasExplicitItems {
			qty, ok := requested[line.deliveryItemID]
			if !ok {
				continue
			}
			line.qty = qty
			delete(requested, line.deliveryItemID)
		} else {
			line.qty = line.openQty
		}
		if line.openQty <= 0 {
			return nil, fmt.Errorf("delivery item %d is fully billed", line.itemNo)
		}
		if line.qty <= 0 {
			return nil, fmt.Errorf("billing qty for delivery item %d must be greater than zero", line.itemNo)
		}
		if line.qty-line.openQty > 0.0001 {
			return nil, fmt.Errorf("billing qty %.4f exceeds open billing qty %.4f for delivery item %d", line.qty, line.openQty, line.itemNo)
		}
		line.net = roundMoney(line.qty * line.unitPrice * (1 - line.discountPct/100))
		netTotal += line.net
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return nil, err
	}
	rows.Close()
	if len(requested) > 0 {
		return nil, fmt.Errorf("one or more selected delivery items are not valid for this delivery")
	}
	if len(lines) == 0 {
		return nil, fmt.Errorf("delivery has no billable items")
	}
	taxTotal := 0.0
	taxRate := 0.0
	if soTax > 0 && soNet > 0 {
		taxRate = soTax / soNet
		for i := range lines {
			if i == len(lines)-1 {
				lines[i].tax = roundMoney((netTotal * taxRate) - taxTotal)
			} else {
				lines[i].tax = roundMoney(lines[i].net * taxRate)
				taxTotal += lines[i].tax
			}
			lines[i].total = roundMoney(lines[i].net + lines[i].tax)
		}
	} else {
		for i := range lines {
			lines[i].total = lines[i].net
		}
	}
	taxTotal = 0
	totalAmount := 0.0
	for _, line := range lines {
		taxTotal += line.tax
		totalAmount += line.total
	}
	netTotal = roundMoney(netTotal)
	taxTotal = roundMoney(taxTotal)
	totalAmount = roundMoney(totalAmount)

	invoiceID := uuid.New()
	invoiceNo := r.nextSalesInvoiceNo(ctx, tenantID, invoiceDate)
	_, err = tx.Exec(ctx, `INSERT INTO sales_invoices
		(id, tenant_id, invoice_no, delivery_id, sales_order_id, customer_id, invoice_date, currency,
		 net_amount, tax_amount, total_amount, status, created_by, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'DRAFT',$12,NOW(),NOW())`,
		invoiceID, tenantID, invoiceNo, deliveryID, soID, customerID, invoiceDate, currency, netTotal, taxTotal, totalAmount, userID)
	if err != nil {
		return nil, fmt.Errorf("insert sales invoice: %w", err)
	}
	for _, line := range lines {
		invoiceItemID := uuid.New()
		_, err = tx.Exec(ctx, `INSERT INTO sales_invoice_items
			(id, invoice_id, delivery_item_id, so_item_id, item_no, product_id, quantity, unit_of_measure,
			 unit_price, discount_pct, net_amount, tax_amount, line_total)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
			invoiceItemID, invoiceID, line.deliveryItemID, line.soItemID, line.itemNo, line.productID, line.qty, line.uom,
			line.unitPrice, line.discountPct, line.net, line.tax, line.total)
		if err != nil {
			return nil, fmt.Errorf("insert sales invoice item: %w", err)
		}
		if line.tax > 0 {
			_, err = tx.Exec(ctx, `INSERT INTO invoice_tax_details
				(tenant_id, invoice_id, invoice_item_id, tax_code, jurisdiction, tax_rate, taxable_amount, tax_amount)
				VALUES ($1,$2,$3,'tax_output','', $4, $5, $6)`,
				tenantID, invoiceID, invoiceItemID, taxRate, line.net, line.tax)
			if err != nil {
				return nil, fmt.Errorf("insert invoice tax detail: %w", err)
			}
		}
		_, err = tx.Exec(ctx, `INSERT INTO delivery_billing_status
			(tenant_id, delivery_id, delivery_item_id, pgi_qty, billed_qty, status, updated_at)
			VALUES ($1,$2,$3,$4::numeric,$5::numeric, CASE WHEN $5::numeric >= $4::numeric THEN 'FULLY_BILLED' ELSE 'PARTIALLY_BILLED' END, NOW())
			ON CONFLICT (tenant_id, delivery_item_id) DO UPDATE SET
				pgi_qty = EXCLUDED.pgi_qty,
				billed_qty = delivery_billing_status.billed_qty + $5::numeric,
				status = CASE WHEN delivery_billing_status.billed_qty + $5::numeric >= EXCLUDED.pgi_qty THEN 'FULLY_BILLED' ELSE 'PARTIALLY_BILLED' END,
				updated_at = NOW()`,
			tenantID, deliveryID, line.deliveryItemID, line.deliveryQty, line.qty)
		if err != nil {
			return nil, fmt.Errorf("update delivery billing status: %w", err)
		}
	}
	if req.PostImmediately {
		if _, err := r.postSalesInvoiceTx(ctx, tx, invoiceID, tenantID, userID, warehouseID); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetSalesInvoice(ctx, invoiceID, tenantID)
}

func (r *SalesRepo) PostSalesInvoice(ctx context.Context, id, tenantID, userID uuid.UUID) (*salesmodels.SalesInvoice, error) {
	if err := r.ensureInvoiceTables(ctx); err != nil {
		return nil, err
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	var warehouseID uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT dn.warehouse_id
		FROM sales_invoices si
		JOIN sales_delivery_notes dn ON dn.id=si.delivery_id
		WHERE si.id=$1 AND si.tenant_id=$2`, id, tenantID).Scan(&warehouseID); err != nil {
		return nil, err
	}
	if _, err := r.postSalesInvoiceTx(ctx, tx, id, tenantID, userID, warehouseID); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetSalesInvoice(ctx, id, tenantID)
}

func (r *SalesRepo) postSalesInvoiceTx(ctx context.Context, tx pgx.Tx, id, tenantID, userID, warehouseID uuid.UUID) (uuid.UUID, error) {
	var status, invoiceNo string
	var invoiceDate time.Time
	var soID uuid.UUID
	var netAmount, taxAmount, totalAmount float64
	err := tx.QueryRow(ctx, `SELECT status, invoice_no, invoice_date, sales_order_id,
			net_amount::float8, tax_amount::float8, total_amount::float8
		FROM sales_invoices WHERE id=$1 AND tenant_id=$2 FOR UPDATE`,
		id, tenantID).Scan(&status, &invoiceNo, &invoiceDate, &soID, &netAmount, &taxAmount, &totalAmount)
	if err != nil {
		return uuid.Nil, err
	}
	if status == "POSTED" {
		return uuid.Nil, fmt.Errorf("invoice already posted")
	}
	orgID, err := salesResolveOrgForWarehouseTx(ctx, tx, tenantID, warehouseID)
	if err != nil {
		return uuid.Nil, err
	}
	arAccountID, err := salesAccountForTypeTx(ctx, tx, orgID, "AR_RECON")
	if err != nil {
		return uuid.Nil, fmt.Errorf("no AR_RECON account configured in Finance Settings (Account Types tab) for org %s; cannot post sales invoice", orgID)
	}
	revenueAccountID, err := salesAccountForAnyTypeTx(ctx, tx, orgID, "sales_rev", "SALES_REV")
	if err != nil {
		return uuid.Nil, fmt.Errorf("no sales_rev account configured in Finance Settings (Account Types tab) for org %s; cannot post sales invoice", orgID)
	}
	lines := []salesJournalLine{
		{accountID: arAccountID, debit: totalAmount, description: fmt.Sprintf("Customer invoice %s AR", invoiceNo)},
		{accountID: revenueAccountID, credit: netAmount, description: fmt.Sprintf("Customer invoice %s sales revenue", invoiceNo)},
	}
	if taxAmount > 0 {
		taxAccountID, err := salesAccountForAnyTypeTx(ctx, tx, orgID, "tax_output", "TAX_OUTPUT")
		if err != nil {
			return uuid.Nil, fmt.Errorf("no tax_output account configured in Finance Settings (Account Types tab) for org %s; cannot post sales invoice", orgID)
		}
		lines = append(lines, salesJournalLine{accountID: taxAccountID, credit: taxAmount, description: fmt.Sprintf("Customer invoice %s output tax", invoiceNo)})
	}
	entryID, err := salesInsertPostedJournalTx(ctx, tx, tenantID, userID, orgID, invoiceDate, fmt.Sprintf("Sales Invoice - %s", invoiceNo), invoiceNo, lines)
	if err != nil {
		return uuid.Nil, err
	}
	_, err = tx.Exec(ctx, `UPDATE sales_invoices
		SET status='POSTED', journal_entry_id=$3, posted_at=NOW(), updated_at=NOW()
		WHERE id=$1 AND tenant_id=$2`, id, tenantID, entryID)
	if err != nil {
		return uuid.Nil, err
	}
	_, _ = tx.Exec(ctx, `UPDATE sales_billing_queue SET status = CASE
			WHEN NOT EXISTS (
				SELECT 1
				FROM sales_delivery_note_items dni
				JOIN sales_delivery_notes dn ON dn.id=dni.delivery_id
				LEFT JOIN (
					SELECT sii.delivery_item_id, SUM(sii.quantity) AS billed_qty
					FROM sales_invoice_items sii
					JOIN sales_invoices si ON si.id=sii.invoice_id
					WHERE si.tenant_id=$2 AND si.status <> 'CANCELLED'
					GROUP BY sii.delivery_item_id
				) billed ON billed.delivery_item_id=dni.id
				WHERE dn.id=sales_billing_queue.delivery_id
				  AND dni.delivery_qty > COALESCE(billed.billed_qty,0)
			) THEN 'INVOICED' ELSE 'PARTIAL' END
		WHERE delivery_id=(SELECT delivery_id FROM sales_invoices WHERE id=$1)`, id, tenantID)
	_, _ = tx.Exec(ctx, `UPDATE sales_orders SET status='INVOICED', updated_at=NOW()
		WHERE id=$1 AND tenant_id=$2
		  AND NOT EXISTS (
			SELECT 1
			FROM sales_delivery_notes dn
			JOIN sales_delivery_note_items dni ON dni.delivery_id=dn.id
			LEFT JOIN (
				SELECT sii.delivery_item_id, SUM(sii.quantity) AS billed_qty
				FROM sales_invoice_items sii
				JOIN sales_invoices si ON si.id=sii.invoice_id
				WHERE si.tenant_id=$2 AND si.status <> 'CANCELLED'
				GROUP BY sii.delivery_item_id
			) billed ON billed.delivery_item_id=dni.id
			WHERE dn.sales_order_id=$1 AND dn.tenant_id=$2 AND dn.status='PGI_POSTED'
			  AND dni.delivery_qty > COALESCE(billed.billed_qty,0)
		  )`, soID, tenantID)
	return entryID, nil
}

func (r *SalesRepo) ListSalesInvoices(ctx context.Context, tenantID uuid.UUID, status string) ([]*salesmodels.SalesInvoice, error) {
	if err := r.ensureInvoiceTables(ctx); err != nil {
		return nil, err
	}
	query := `SELECT si.id, si.tenant_id, si.invoice_no, si.delivery_id, COALESCE(dn.delivery_no,''),
			si.sales_order_id, COALESCE(so.so_number,''), si.customer_id, COALESCE(c.customer_code,''), COALESCE(c.name,''),
			si.invoice_date, si.currency, si.net_amount::float8, si.tax_amount::float8, si.total_amount::float8,
			si.status, si.journal_entry_id, COALESCE(je.document_no,''), COALESCE(je.description,''),
			si.created_by, si.created_at, si.updated_at, si.posted_at
		FROM sales_invoices si
		LEFT JOIN sales_delivery_notes dn ON dn.id=si.delivery_id
		LEFT JOIN sales_orders so ON so.id=si.sales_order_id
		LEFT JOIN customers c ON c.id=si.customer_id
		LEFT JOIN gl_journal_entries je ON je.id=si.journal_entry_id
		WHERE si.tenant_id=$1`
	args := []interface{}{tenantID}
	if status != "" {
		query += " AND si.status=$2"
		args = append(args, status)
	}
	query += " ORDER BY si.created_at DESC"
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*salesmodels.SalesInvoice
	for rows.Next() {
		inv := &salesmodels.SalesInvoice{}
		if err := rows.Scan(&inv.ID, &inv.TenantID, &inv.InvoiceNo, &inv.DeliveryID, &inv.DeliveryNo,
			&inv.SalesOrderID, &inv.SONumber, &inv.CustomerID, &inv.CustomerCode, &inv.CustomerName,
			&inv.InvoiceDate, &inv.Currency, &inv.NetAmount, &inv.TaxAmount, &inv.TotalAmount,
			&inv.Status, &inv.JournalEntryID, &inv.JournalEntryNo, &inv.JournalEntryDescription,
			&inv.CreatedBy, &inv.CreatedAt, &inv.UpdatedAt, &inv.PostedAt); err != nil {
			return nil, err
		}
		list = append(list, inv)
	}
	return list, rows.Err()
}

func (r *SalesRepo) GetSalesInvoice(ctx context.Context, id, tenantID uuid.UUID) (*salesmodels.SalesInvoice, error) {
	list, err := r.ListSalesInvoices(ctx, tenantID, "")
	if err != nil {
		return nil, err
	}
	var inv *salesmodels.SalesInvoice
	for _, row := range list {
		if row.ID == id {
			inv = row
			break
		}
	}
	if inv == nil {
		return nil, pgx.ErrNoRows
	}
	rows, err := r.db.Query(ctx, `SELECT sii.id, sii.invoice_id, sii.delivery_item_id, sii.so_item_id, sii.item_no,
			sii.product_id, COALESCE(p.sku,''), COALESCE(p.name,''), sii.quantity::float8, COALESCE(sii.unit_of_measure,'EA'),
			sii.unit_price::float8, sii.discount_pct::float8, sii.net_amount::float8, sii.tax_amount::float8, sii.line_total::float8,
			sii.created_at
		FROM sales_invoice_items sii
		LEFT JOIN products p ON p.id=sii.product_id
		WHERE sii.invoice_id=$1
		ORDER BY sii.item_no`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var item salesmodels.SalesInvoiceItem
		if err := rows.Scan(&item.ID, &item.InvoiceID, &item.DeliveryItemID, &item.SOItemID, &item.ItemNo,
			&item.ProductID, &item.SKUCode, &item.GoodsName, &item.Quantity, &item.UnitOfMeasure,
			&item.UnitPrice, &item.DiscountPct, &item.NetAmount, &item.TaxAmount, &item.LineTotal, &item.CreatedAt); err != nil {
			return nil, err
		}
		inv.Items = append(inv.Items, item)
	}
	return inv, rows.Err()
}

func salesAccountForAnyTypeTx(ctx context.Context, tx pgx.Tx, orgID uuid.UUID, accountTypes ...string) (uuid.UUID, error) {
	for _, accountType := range accountTypes {
		accountID, err := salesAccountForTypeTx(ctx, tx, orgID, accountType)
		if err == nil && accountID != uuid.Nil {
			return accountID, nil
		}
	}
	return uuid.Nil, fmt.Errorf("account types %v not configured for org %s", accountTypes, orgID)
}

func roundMoney(v float64) float64 {
	return math.Round(v*100) / 100
}
