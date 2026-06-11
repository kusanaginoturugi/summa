package main

import (
	"strconv"
	"strings"
)

var currencySymbols = map[string]string{
	"USD": "$",
	"EUR": "€",
	"GBP": "£",
	"JPY": "¥",
	"CNY": "¥",
	"INR": "₹",
	"RUB": "₽",
	"KRW": "₩",
	"BRL": "R$",
	"SGD": "SGD$",
}

var currencyFractionDigits = map[string]int{
	"JPY": 0,
}

func formatCurrency(currency string, amount float64) string {
	digits := 2
	if value, ok := currencyFractionDigits[currency]; ok {
		digits = value
	}

	formatted := formatNumber(strconv.FormatFloat(amount, 'f', digits, 64))
	if currency == "JPY" {
		return formatted + " 円"
	}

	return currencySymbols[currency] + formatted
}

func formatNumber(amount string) string {
	sign := ""
	if strings.HasPrefix(amount, "-") {
		sign = "-"
		amount = strings.TrimPrefix(amount, "-")
	}

	integerPart, fractionalPart, hasFraction := strings.Cut(amount, ".")
	var grouped strings.Builder
	for i, digit := range integerPart {
		if i > 0 && (len(integerPart)-i)%3 == 0 {
			grouped.WriteByte(',')
		}
		grouped.WriteRune(digit)
	}

	if hasFraction {
		return sign + grouped.String() + "." + fractionalPart
	}

	return sign + grouped.String()
}
