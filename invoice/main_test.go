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

func TestDocumentLinesAcceptsActualAndEscapedNewlines(t *testing.T) {
	tests := []struct {
		name string
		text string
		want []string
	}{
		{
			name: "actual newlines",
			text: "管理画面の改修\nPDF出力対応",
			want: []string{"管理画面の改修", "PDF出力対応"},
		},
		{
			name: "escaped newlines",
			text: `管理画面の改修\nPDF出力対応`,
			want: []string{"管理画面の改修", "PDF出力対応"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := documentLines(tt.text)
			if len(got) != len(tt.want) {
				t.Fatalf("documentLines(%q) returned %d lines, want %d", tt.text, len(got), len(tt.want))
			}
			for i := range tt.want {
				if got[i] != tt.want[i] {
					t.Fatalf("documentLines(%q)[%d] = %q, want %q", tt.text, i, got[i], tt.want[i])
				}
			}
		})
	}
}
