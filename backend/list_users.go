package main

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, "host=localhost port=5432 user=swiftai password=*** dbname=swiftai_erp sslmode=disable")
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	rows, err := pool.Query(ctx, "SELECT id, email, is_active FROM users")
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	fmt.Println("Users in database:")
	for rows.Next() {
		var id, email string
		var active bool
		rows.Scan(&id, &email, &active)
		fmt.Printf("  %s | %s | active=%v\n", id, email, active)
	}
}
