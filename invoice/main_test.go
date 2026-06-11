package main

import "testing"

func TestDefaultEstimate(t *testing.T) {
	estimate := DefaultEstimate()

	if estimate.Title != "見積書" {
		t.Fatalf("Title = %q, want %q", estimate.Title, "見積書")
	}
	if estimate.Due == "" {
		t.Fatal("Due must not be empty")
	}
}
