package database

import (
	"fmt"

	"github.com/nats-io/nats.go"
	"github.com/rs/zerolog/log"
	"github.com/swiftai-erp/backend/internal/config"
)

// NewNATSConn creates a NATS JetStream connection.
func NewNATSConn(cfg config.NATSConfig) (*nats.Conn, error) {
	nc, err := nats.Connect(cfg.URL, nats.Name("swiftai-erp"))
	if err != nil {
		return nil, fmt.Errorf("connect to nats: %w", err)
	}

	log.Info().Str("url", cfg.URL).Msg("nats connection established")
	return nc, nil
}
