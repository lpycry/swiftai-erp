package engine

import (
	"testing"

	"github.com/swiftai-erp/backend/internal/authz/models"
)

func TestMatchFieldValues(t *testing.T) {
	engine := &PermissionEngine{}

	if !engine.matchFieldValues(&models.RoleAuthValue{}, nil) {
		t.Fatal("unrestricted auth value should pass without request fields")
	}

	restricted := &models.RoleAuthValue{
		FieldValues: map[string]string{
			"company_code": "USA01,USA02",
		},
		FieldRanges: map[string]models.FieldRange{
			"plant": {From: "1000", To: "1999"},
		},
	}

	if engine.matchFieldValues(restricted, nil) {
		t.Fatal("restricted auth value must not pass without request fields")
	}
	if engine.matchFieldValues(restricted, map[string]string{"company_code": "USA01"}) {
		t.Fatal("restricted auth value must require all configured fields")
	}
	if !engine.matchFieldValues(restricted, map[string]string{
		"company_code": "USA02",
		"plant":        "1200",
	}) {
		t.Fatal("configured value and range should pass")
	}
	if engine.matchFieldValues(restricted, map[string]string{
		"company_code": "USA03",
		"plant":        "1200",
	}) {
		t.Fatal("unconfigured value should be denied")
	}
}
