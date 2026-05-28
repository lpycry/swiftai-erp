package main

import (
    "context"
    "fmt"
    "os"

    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/swiftai-erp/backend/internal/config"
)

func main() {
    cfg, err := config.Load("config/config.dev.yaml")
    if err != nil { fmt.Fprintln(os.Stderr, "config error:", err); os.Exit(1) }
    pool, err := pgxpool.New(context.Background(), cfg.Database.DSN())
    if err != nil { fmt.Fprintln(os.Stderr, "db error:", err); os.Exit(1) }
    defer pool.Close()

    // Find a receipt from USA01 org
    var rid, poID, orgID, itemID string
    var qty, cost, total float64
    var binID *string
    err = pool.QueryRow(context.Background(), `
        SELECT r.id, r.po_id, r.org_id, r.item_id, r.bin_id, r.quantity, r.unit_cost, r.total_cost
        FROM purchase_receipts r
        WHERE r.is_reversed = false
          AND EXISTS (SELECT 1 FROM org_reconciliation_accounts WHERE org_id = r.org_id AND account_type = 'INVENTORY')
        ORDER BY r.created_at DESC LIMIT 1
    `).Scan(&rid, &poID, &orgID, &itemID, &binID, &qty, &cost, &total)
    if err != nil {
        fmt.Println("No testable receipt:", err)
        return
    }
    fmt.Printf("Receipt: id=%s po=%s org=%s\n", rid[:8], poID[:8], orgID[:8])

    // Check stock_movements columns
    fmt.Println("\n=== stock_movements created_by ===")
    var isnull, cn string
    pool.QueryRow(context.Background(), `
        SELECT column_name, is_nullable FROM information_schema.columns
        WHERE table_name='stock_movements' AND column_name='created_by'`).Scan(&cn, &isnull)
    fmt.Printf("  %s nullable=%s\n", cn, isnull)

    // Check if userID is passed correctly from receipt
    fmt.Println("\n=== Check existing stock_movements data ===")
    var cb, txType string
    err = pool.QueryRow(context.Background(), `
        SELECT created_by::text, transaction_type FROM stock_movements LIMIT 1`).Scan(&cb, &txType)
    if err != nil { fmt.Println("  no movements:", err) } else {
        fmt.Printf("  created_by=%s type=%s\n", cb[:8], txType)
    }

    // Check gl_journal_entries for receipt
    fmt.Println("\n=== Check JE for receipt ===")
    prefix := rid[:8]
    var jeID string
    err = pool.QueryRow(context.Background(), `
        SELECT id::text FROM gl_journal_entries
        WHERE description ILIKE '%' || $1 || '%' AND source = 'purchase' LIMIT 1
    `, "%Receipt%"+prefix+"%").Scan(&jeID)
    if err != nil {
        fmt.Printf("  JE not found: %v\n", err)
    } else {
        fmt.Printf("  JE=%s\n", jeID[:8])
    }

    // Test the reverse directly
    fmt.Println("\n=== Attempting reverse... ===")
    rID, _ := uuid.Parse(rid)
    oID, _ := uuid.Parse(orgID)

    // Try the reverse repo function directly
    _, err = pool.Exec(context.Background(), `
        UPDATE purchase_order_items SET received_quantity = GREATEST(0, received_quantity - $1)
        WHERE po_id = $2 AND item_id = $3
    `, qty, poID, itemID)
    if err != nil {
        fmt.Printf("  PO item revert FAILED: %v\n", err)
    } else {
        fmt.Println("  PO item revert OK")
        // Rollback
        pool.Exec(context.Background(), `
            UPDATE purchase_order_items SET received_quantity = received_quantity + $1
            WHERE po_id = $2 AND item_id = $3
        `, qty, poID, itemID)
    }

    // Test stock_items update with nil binID
    fmt.Println("\n=== Stock revert test ===")
    var whID string
    if binID != nil {
        err = pool.QueryRow(context.Background(), `SELECT warehouse_id::text FROM bins WHERE id = $1`, *binID).Scan(&whID)
        if err != nil {
            fmt.Printf("  Cannot find warehouse for bin %s: %v\n", *binID, err)
        } else {
            fmt.Printf("  warehouse=%s\n", whID[:8])
        }
    } else {
        fmt.Println("  No bin_id - skipping stock revert")
    }
}
