class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy export generate_pdf]

  def index
    @invoices = Invoice.order(invoice_date: :desc, invoice_number: :desc)
  end

  def show
  end

  def new
    @invoice = Invoice.new(invoice_date: default_invoice_date)
  end

  def create
    @invoice = Invoice.new(invoice_params)

    if @invoice.valid?
      @invoice.save_with_voucher!
      redirect_to @invoice, notice: t("invoices.flash.saved")
    else
      flash.now[:alert] = @invoice.errors.full_messages.join(" / ")
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.join(" / ")
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @invoice.assign_attributes(invoice_params)
    if @invoice.valid?
      @invoice.update_with_voucher!(invoice_params)
      redirect_to @invoice, notice: t("invoices.flash.updated")
    else
      flash.now[:alert] = @invoice.errors.full_messages.join(" / ")
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.join(" / ")
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @invoice.destroy
    redirect_to invoices_path, notice: t("invoices.flash.deleted")
  end

  def export
    send_data JSON.pretty_generate(@invoice.invoice_payload),
      filename: "#{@invoice.invoice_number}.json",
      type: "application/json"
  end

  def generate_pdf
    InvoicePdfGenerator.new(@invoice).generate!
    redirect_to @invoice, notice: t("invoices.flash.pdf_generated")
  rescue InvoicePdfGenerator::Error, InvoicePdfValidator::Error => e
    redirect_to @invoice, alert: e.message
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:invoice_number, :issuer, :client_name, :invoice_date, :due_date, :title, :items_json, :note)
  end

  def default_invoice_date
    Date.new(current_fiscal_year, Date.current.month, Date.current.day)
  rescue Date::Error
    Date.current
  end
end
