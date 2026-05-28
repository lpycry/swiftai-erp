package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/swiftai-erp/backend/internal/config"
)

func main() {
	cfgPath := "config/config.dev.yaml"
	if len(os.Args) > 1 {
		cfgPath = os.Args[1]
	}
	if len(os.Args) > 2 {
		fmt.Println("Usage: run-migration [config-path]")
		os.Exit(1)
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	ctx := context.Background()
	dsn := cfg.Database.DSN()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to connect: %v\n", err)
		os.Exit(1)
	}
	defer pool.Close()

	// Migration 009: payment_terms + incoterms
	migrationPath := "migrations/009_finance_settings.sql"
	sql, err := os.ReadFile(migrationPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read migration: %v\n", err)
		os.Exit(1)
	}

	_, err = pool.Exec(ctx, string(sql))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Migration failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Migration 009 applied successfully (payment_terms + incoterms)")

	// Migration 011: account_type on org_reconciliation_accounts
	migrationPath11 := "migrations/011_finance_settings_type.sql"
	sql11, err := os.ReadFile(migrationPath11)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read migration 011: %v\n", err)
		os.Exit(1)
	}

	_, err = pool.Exec(ctx, string(sql11))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Migration 011 failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Migration 011 applied successfully (account_type on org_reconciliation_accounts)")

	// Migration 012: receipt reversal columns (run independently, 011 may already exist)
	_ = pool.Exec(ctx, string(sql11)) // ignore error if 011 already applied

	// Migration 012: receipt reversal columns
	migrationPath12 := "migrations/012_receipt_reversal.sql"
	sql12, err := os.ReadFile(migrationPath12)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read migration 012: %v\n", err)
		os.Exit(1)
	}

	_, err = pool.Exec(ctx, string(sql12))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Migration 012 failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Migration 012 applied successfully (receipt reversal columns)")
}
