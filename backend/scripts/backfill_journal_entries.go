package main

import (
    "context"
    "fmt"
    "os"
    "time"

    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/swiftai-erp/backend/internal/config"
    glmodels "github.com/swiftai-erp/backend/internal/gl/models"
    glsvc "github.com/swiftai-erp/backend/internal/gl/service"
    glrepo "github.com/swiftai-erp/backend/internal/gl/repository"
)

func main() {
    cfgPath := "config/config.dev.yaml"
    if len(os.Args) > 1 { cfgPath = os.Args[1] }

    cfg, err := config.Load(cfgPath)
    if err != nil { fmt.Fprintln(os.Stderr, "config error:", err); os.Exit(1) }
    pool, err := pgxpool.New(context.Background(), cfg.Database.DSN())
    if err != nil { fmt.Fprintln(os.Stderr, "db error:", err); os.Exit(1) }
    defer pool.Close()

    glRepo := glrepo.NewGLRepo(pool)
    glSvc := glsvc.NewGLService(glRepo, nil, cfg)

    // Find all receipts that have NO linked journal entry
    fmt.Println("Searching for receipts without journal entries...")
    rrows, _ := pool.Query(context.Background(), `
        SELECT r.id, r.po_id, r.item_id, r.item_sku, r.item_name,
               r.quantity, r.unit_cost, r.created_at,
               po.organization_id, po.vendor_id, po.po_number
        FROM purchase_receipts r
        JOIN purchase_orders po ON po.id = r.po_id
        WHERE NOT EXISTS (
            SELECT 1 FROM gl_journal_entries je
            WHERE je.description ILIKE '%Receipt%' || substring(r.id::text, 1, 8) || '%'
              AND je.source = 'purchase'
        )
        ORDER BY r.created_at DESC`)
    defer rrows.Close()

    var count int
    var failures int
    for rrows.Next() {
        var rid, poID, itemID, sku, itemName, createdStr, orgID, vendorID, poNo string
        var qty, cost float64
        rrows.Scan(&rid, &poID, &itemID, &sku, &itemName, &qty, &cost, &createdStr, &orgID, &vendorID, &poNo)

        // Parse org UUID
        realOrgID, _ := uuid.Parse(orgID)
        vendorUUID, _ := uuid.Parse(vendorID)
        receiptUUID, _ := uuid.Parse(rid)

        // Find INVENTORY account for this org
        var inventoryID uuid.UUID
        err := pool.QueryRow(context.Background(),
            `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'INVENTORY'`,
            realOrgID).Scan(&inventoryID)
        if err != nil || inventoryID == uuid.Nil {
            fmt.Printf("  SKIP receipt=%s: no INVENTORY account for org %s. Configure in Account Types tab first.\n",
                rid[:8], orgID[:8])
            failures++
            continue
        }

        // Find GR_IR account for this org
        var grIrID uuid.UUID
        err = pool.QueryRow(context.Background(),
            `SELECT account_id FROM org_reconciliation_accounts WHERE org_id = $1 AND account_type = 'GR_IR'`,
            realOrgID).Scan(&grIrID)
        if err != nil || grIrID == uuid.Nil {
            fmt.Printf("  SKIP receipt=%s: no GR_IR account for org %s. Configure in Account Types tab first.\n",
                rid[:8], orgID[:8])
            failures++
            continue
        }

        totalAmount := qty * cost
        now := time.Now()
        description := fmt.Sprintf("Goods Receipt - PO %s / Receipt %s (backfill)", poNo, rid[:8])

        entryReq := &glmodels.CreateJournalEntryRequest{
            PostingDate:    now,
            Description:    description,
            Reference:      poNo,
            EntryType:      "normal",
            Source:         "purchase",
            OrganizationID: &realOrgID,
            Lines: []glmodels.CreateJournalLineRequest{
                {
                    AccountID:   inventoryID,
                    Debit:       totalAmount,
                    Credit:      0,
                    Description: fmt.Sprintf("GR: %s - %s x %.2f @ %.2f", sku, itemName, qty, cost),
                    PartnerID:   &vendorUUID,
                    PartnerType: "vendor",
                },
                {
                    AccountID:   grIrID,
                    Debit:       0,
                    Credit:      totalAmount,
                    Description: fmt.Sprintf("GR: %s - %s x %.2f @ %.2f", sku, itemName, qty, cost),
                    PartnerID:   &vendorUUID,
                    PartnerType: "vendor",
                },
            },
        }

        // Create as draft
        entry, err := glSvc.CreateJournalEntry(context.Background(), realOrgID, uuid.Nil, entryReq)
        if err != nil {
            fmt.Printf("  FAIL receipt=%s: create JE: %v\n", rid[:8], err)
            failures++
            continue
        }

        // Post immediately
        _, err = glSvc.UpdateJournalEntryStatus(context.Background(), entry.ID, realOrgID, uuid.Nil, "posted")
        if err != nil {
            fmt.Printf("  FAIL receipt=%s: post JE: %v\n", rid[:8], err)
            failures++
            continue
        }

        fmt.Printf("  OK   receipt=%s → JE=%s (Dr INVENTORY %.2f / Cr GR_IR %.2f)\n",
            rid[:8], entry.ID.String()[:8], totalAmount, totalAmount)
        count++
    }

    fmt.Printf("\nDone! Created %d journal entries (%d failures)\n", count, failures)
}
