package service

import "testing"

func TestReceiptDebitAccountTypeForMaterialType(t *testing.T) {
	tests := []struct {
		name         string
		materialType string
		want         string
	}{
		{name: "raw material", materialType: "raw_material", want: "RAW_MAT"},
		{name: "raw material with hyphen", materialType: "raw-material", want: "RAW_MAT"},
		{name: "finished goods", materialType: "finished_goods", want: "FGS"},
		{name: "semi finished goods", materialType: "semi_finished_goods", want: "SFGS"},
		{name: "half finished goods", materialType: "half_finished_goods", want: "SFGS"},
		{name: "work in process", materialType: "work in process", want: "WIP"},
		{name: "other inventory", materialType: "other", want: "Other_Inv"},
		{name: "direct account type", materialType: "PACKAGING_INV", want: "PACKAGING_INV"},
		{name: "empty", materialType: " ", want: ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := receiptDebitAccountTypeForMaterialType(tt.materialType)
			if got != tt.want {
				t.Fatalf("receiptDebitAccountTypeForMaterialType(%q) = %q, want %q", tt.materialType, got, tt.want)
			}
		})
	}
}
