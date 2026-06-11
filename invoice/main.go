package main

import (
	_ "embed"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/signintech/gopdf"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

//go:embed "fonts/Jigmo.ttf"
var jigmoFont []byte

//go:embed "fonts/Jigmo.ttf"
var jigmoBoldFont []byte

type Invoice struct {
	Id    string `json:"id" yaml:"id"`
	Title string `json:"title" yaml:"title"`

	Logo string `json:"logo" yaml:"logo"`
	From string `json:"from" yaml:"from"`
	To   string `json:"to" yaml:"to"`
	Date string `json:"date" yaml:"date"`
	Due  string `json:"due" yaml:"due"`

	Items      []string  `json:"items" yaml:"items"`
	Quantities []int     `json:"quantities" yaml:"quantities"`
	Rates      []float64 `json:"rates" yaml:"rates"`

	Tax      float64 `json:"tax" yaml:"tax"`
	Discount float64 `json:"discount" yaml:"discount"`
	Currency string  `json:"currency" yaml:"currency"`

	Note string `json:"note" yaml:"note"`
}

type documentLabels struct {
	recipient string
	due       string
}

func DefaultInvoice() Invoice {
	return Invoice{
		Id:         time.Now().Format("20060102"),
		Title:      "請求書",
		Rates:      []float64{25},
		Quantities: []int{2},
		Items:      []string{"Paper Cranes"},
		From:       "Project Folded, Inc.",
		To:         "Untitled Corporation, Inc.",
		Date:       time.Now().Format("2006/01/02"),
		Due:        time.Now().AddDate(0, 0, 14).Format("2006/01/02"),
		Tax:        0,
		Discount:   0,
		Currency:   "USD",
	}
}

func DefaultEstimate() Invoice {
	estimate := DefaultInvoice()
	estimate.Title = "見積書"
	estimate.Due = time.Now().AddDate(0, 1, 0).Format("2006/01/02")
	return estimate
}

var (
	invoiceImportPath  string
	invoiceOutput      string
	invoiceFile        = Invoice{}
	estimateImportPath string
	estimateOutput     string
	estimateFile       = Invoice{}
)

func init() {
	viper.AutomaticEnv()

	addDocumentFlags(generateCmd, &invoiceFile, DefaultInvoice(), &invoiceImportPath, &invoiceOutput, "invoice.pdf")
	addDocumentFlags(estimateCmd, &estimateFile, DefaultEstimate(), &estimateImportPath, &estimateOutput, "estimate.pdf")
}

func addDocumentFlags(cmd *cobra.Command, document *Invoice, defaults Invoice, importPath, output *string, outputName string) {
	cmd.Flags().StringVar(importPath, "import", "", "Imported file (.json/.yaml)")
	cmd.Flags().StringVar(&document.Id, "id", defaults.Id, "ID")
	cmd.Flags().StringVar(&document.Title, "title", defaults.Title, "Title")

	cmd.Flags().Float64SliceVarP(&document.Rates, "rate", "r", defaults.Rates, "Rates")
	cmd.Flags().IntSliceVarP(&document.Quantities, "quantity", "q", defaults.Quantities, "Quantities")
	cmd.Flags().StringSliceVarP(&document.Items, "item", "i", defaults.Items, "Items")

	cmd.Flags().StringVarP(&document.Logo, "logo", "l", defaults.Logo, "Company logo")
	cmd.Flags().StringVarP(&document.From, "from", "f", defaults.From, "Issuing company")
	cmd.Flags().StringVarP(&document.To, "to", "t", defaults.To, "Recipient company")
	cmd.Flags().StringVar(&document.Date, "date", defaults.Date, "Date")
	cmd.Flags().StringVar(&document.Due, "due", defaults.Due, "Due date")

	cmd.Flags().Float64Var(&document.Tax, "tax", defaults.Tax, "Tax")
	cmd.Flags().Float64VarP(&document.Discount, "discount", "d", defaults.Discount, "Discount")
	cmd.Flags().StringVarP(&document.Currency, "currency", "c", defaults.Currency, "Currency")

	cmd.Flags().StringVarP(&document.Note, "note", "n", defaults.Note, "Note")
	cmd.Flags().StringVarP(output, "output", "o", outputName, "Output file (.pdf)")
}

var rootCmd = &cobra.Command{
	Use:   "invoice",
	Short: "Invoice generates invoices from the command line.",
	Long:  `Invoice generates invoices from the command line.`,
}

var generateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate an invoice",
	Long:  `Generate an invoice`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return generateDocument(cmd, &invoiceFile, invoiceImportPath, invoiceOutput, documentLabels{
			recipient: "請求先",
			due:       "支払期限",
		})
	},
}

var estimateCmd = &cobra.Command{
	Use:   "estimate",
	Short: "Generate an estimate",
	Long:  `Generate an estimate`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return generateDocument(cmd, &estimateFile, estimateImportPath, estimateOutput, documentLabels{
			recipient: "見積先",
			due:       "見積有効期限",
		})
	},
}

func generateDocument(cmd *cobra.Command, document *Invoice, importPath, output string, labels documentLabels) error {
	if importPath != "" {
		err := importData(importPath, document, cmd.Flags())
		if err != nil {
			return err
		}
	}

	pdf := gopdf.GoPdf{}
	pdf.Start(gopdf.Config{
		PageSize: *gopdf.PageSizeA4,
	})
	pdf.SetMargins(40, 40, 40, 40)
	pdf.AddPage()
	err := pdf.AddTTFFontData("Inter", jigmoFont)
	if err != nil {
		return err
	}

	err = pdf.AddTTFFontData("Inter-Bold", jigmoBoldFont)
	if err != nil {
		return err
	}

	writeLogo(&pdf, document.Logo, document.From)
	writeTitle(&pdf, document.Title, document.Id, document.Date)
	writeBillTo(&pdf, labels.recipient, document.To)
	writeHeaderRow(&pdf)
	subtotal := 0.0
	for i := range document.Items {
		q := 1
		if len(document.Quantities) > i {
			q = document.Quantities[i]
		}

		r := 0.0
		if len(document.Rates) > i {
			r = document.Rates[i]
		}

		writeRow(&pdf, document.Currency, document.Items[i], q, r)
		subtotal += float64(q) * r
	}
	if document.Note != "" {
		writeNotes(&pdf, document.Note)
	}
	writeTotals(&pdf, document.Currency, subtotal, subtotal*document.Tax, subtotal*document.Discount)
	if document.Due != "" {
		writeDueDate(&pdf, labels.due, document.Due)
	}
	writeFooter(&pdf, document.Id)
	output = strings.TrimSuffix(output, ".pdf") + ".pdf"
	err = pdf.WritePdf(output)
	if err != nil {
		return err
	}

	fmt.Printf("Generated %s\n", output)

	return nil
}

func main() {
	rootCmd.AddCommand(generateCmd)
	rootCmd.AddCommand(estimateCmd)
	err := rootCmd.Execute()
	if err != nil {
		log.Fatal(err)
	}
}
