package main

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, "host=localhost port=5432 user=swiftai password=*** dbname=swiftai_erp sslmode=disable")
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()

	email := "admin@test.com"
	password := "test123456"

	var userID string
	err = pool.QueryRow(ctx, "SELECT id FROM users WHERE email = $1", email).Scan(&userID)
	if err != nil {
		// Maybe user doesn't exist in this DB - register via API instead
		log.Printf("User lookup failed: %v", err)
		log.Println("Will register via API")
		return
	}
	fmt.Printf("Found user: %s (%s)\n", email, userID)

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatal(err)
	}

	_, err = pool.Exec(ctx, "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2", string(hash), userID)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("Password updated successfully")
}
