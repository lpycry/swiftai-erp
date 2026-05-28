package main

import (
    "context"
    "fmt"
    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/swiftai-erp/backend/internal/config"
)

func main() {
    cfg, err := config.Load("config/config.dev.yaml")
    if err != nil { fmt.Println("config error:", err); return }
    pool, err := pgxpool.New(context.Background(), cfg.Database.DSN())
    if err != nil { fmt.Println("db error:", err); return }
    defer pool.Close()

    // Check table structure
    rows, _ := pool.Query(context.Background(), `
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name = 'org_reconciliation_accounts'
        ORDER BY ordinal_position`)
    for rows.Next() {
        var cn, dt, isnull string; var def *string
        rows.Scan(&cn, &dt, &isnull, &def)
        d := "<nil>"
        if def != nil { d = *def }
        fmt.Printf("%-25s %-15s %-8s %s\n", cn, dt, isnull, d)
    }
    fmt.Println()

    // Check unique constraints
    conrows, _ := pool.Query(context.Background(), `
        SELECT con.conname, pg_get_constraintdef(con.oid)
        FROM pg_constraint con
        WHERE con.conrelid = 'org_reconciliation_accounts'::regclass
          AND con.contype = 'u'`)
    for conrows.Next() {
        var name, def string
        conrows.Scan(&name, &def)
        fmt.Printf("Constraint: %s -> %s\n", name, def)
    }
}
