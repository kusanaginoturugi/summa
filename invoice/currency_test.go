package main

import "testing"

func TestFormatCurrencyAddsThousandsSeparators(t *testing.T) {
	tests := []struct {
		name     string
		currency string
		amount   float64
		want     string
	}{
		{
			name:     "JPY",
			currency: "JPY",
			amount:   25000,
			want:     "25,000 円",
		},
		{
			name:     "USD",
			currency: "USD",
			amount:   1234567.89,
			want:     "$1,234,567.89",
		},
		{
			name:     "unknown currency",
			currency: "XXX",
			amount:   1234567.89,
			want:     "1,234,567.89",
		},
		{
			name:     "negative amount",
			currency: "JPY",
			amount:   -1234567,
			want:     "-1,234,567 円",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := formatCurrency(tt.currency, tt.amount)
			if got != tt.want {
				t.Fatalf("formatCurrency(%q, %v) = %q, want %q", tt.currency, tt.amount, got, tt.want)
			}
		})
	}
}
