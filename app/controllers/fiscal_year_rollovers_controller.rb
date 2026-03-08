require_dependency Rails.root.join("app/services/fiscal_year_rollover_service").to_s

class FiscalYearRolloversController < ApplicationController
  def new
    load_accounts
    assign_form_values
  end

  def create
    load_accounts
    assign_form_values(from_params: true)
    @preview = build_service.preview if params[:preview].present?

    if params[:execute].present?
      voucher = build_service.execute!
      session[:fiscal_year_rollover_balancing_account_code] = @balancing_account_code if @balancing_account_code.present?
      redirect_to edit_voucher_path(voucher), notice: "年度繰越を実行しました。開始残高伝票を作成しています。"
      return
    end

    render :new, status: :ok
  rescue ::FiscalYearRolloverService::Error => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

  def load_accounts
    @accounts = Account.order(:code)
    @equity_accounts = @accounts.select { |account| account.category == "equity" }
  end

  def assign_form_values(from_params: false)
    default_to_year = current_fiscal_year
    default_from_year = current_fiscal_year - 1
    default_balance_code = session[:fiscal_year_rollover_balancing_account_code].presence || @equity_accounts.first&.code

    source = from_params ? rollover_params : params
    @from_year = source[:from_year].presence&.to_i || default_from_year
    @to_year = source[:to_year].presence&.to_i || default_to_year
    @balancing_account_code = source[:balancing_account_code].presence || default_balance_code
    @preview = nil
  end

  def rollover_params
    params.require(:fiscal_year_rollover).permit(:from_year, :to_year, :balancing_account_code)
  end

  def build_service
    @service ||= ::FiscalYearRolloverService.new(
      from_year: @from_year,
      to_year: @to_year,
      balancing_account_code: @balancing_account_code
    )
  end
end
