package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
)

// JSONB is a wrapper for JSONB PostgreSQL fields.
type JSONB map[string]interface{}

func (j JSONB) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	return json.Marshal(j)
}

func (j *JSONB) Scan(value interface{}) error {
	if value == nil {
		*j = nil
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return fmt.Errorf("JSONB scan: expected []byte, got %T", value)
	}
	return json.Unmarshal(bytes, j)
}

// TokenPair for auth responses, shared with JWT package.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	AccessExp    int    `json:"access_expires_in"`
	RefreshExp   int    `json:"refresh_expires_in"`
	TokenType    string `json:"token_type"`
}
