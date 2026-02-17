class VouchersController < ApplicationController
  before_action :set_voucher, only: %i[edit update destroy]

  def index
    @accounts = Account.order(:code)
    @accounts_map = @accounts.pluck(:code, :name).to_h
    @account_code = resolve_account_filter
    @description_filter = resolve_description_filter
    @account_codes = expand_account_codes(@account_code)
    scope = Voucher.includes(:voucher_lines).order(recorded_on: :asc, created_at: :asc)
    if @account_codes.present?
      scope = scope.joins(:voucher_lines).where(voucher_lines: { account_code: @account_codes }).distinct
    end
    if @description_filter.present?
      scope = scope.where("description LIKE ?", "%#{@description_filter}%")
    end
    @vouchers = scope
    line_scope = VoucherLine.where(voucher_id: @vouchers.select(:id))
    if @account_codes.present?
      line_scope = line_scope.where(account_code: @account_codes)
    end
    @total_debit = line_scope.sum(:debit_amount)
    @total_credit = line_scope.sum(:credit_amount)
  end

  def new
    @voucher = Voucher.new(recorded_on: Date.current)
    2.times { @voucher.voucher_lines.build }
    load_accounts
  end

  def create
    @voucher = Voucher.new(voucher_params)
    load_accounts

    if @voucher.save
      ImportRule.record_from_voucher(@voucher)
      redirect_to vouchers_path, notice: t("vouchers.flash.saved")
    else
      @voucher.voucher_lines.build if @voucher.voucher_lines.empty?
      flash.now[:alert] = @voucher.errors.full_messages.join(" / ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_accounts
    load_return_context
  end

  def update
    load_accounts
    load_return_context
    if @voucher.update(voucher_params)
      ImportRule.record_from_voucher(@voucher)
      redirect_to voucher_update_redirect_path, notice: t("vouchers.flash.updated", default: "振替伝票を更新しました")
    else
      flash.now[:alert] = @voucher.errors.full_messages.join(" / ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @voucher.destroy
      redirect_to vouchers_path, notice: t("vouchers.flash.deleted", default: "振替伝票を削除しました")
    else
      redirect_to edit_voucher_path(@voucher), alert: @voucher.errors.full_messages.join(" / ")
    end
  end

  def quick
    load_accounts
    prepare_quick_view
    defaults = quick_defaults
    @form = QuickVoucherForm.new(defaults.merge(recorded_on: defaults[:recorded_on] || Date.current))
  end

  def register
    load_accounts
    @account_code = resolve_register_account
    @description_filter = resolve_register_description_filter
    @edit_line_id = params[:edit_line_id].presence&.to_i
    prepare_register_view
    @entry_form = AccountRegisterEntryForm.new(
      account_code: @account_code,
      recorded_on: resolve_register_recorded_on
    )
  end

  def create_register
    load_accounts
    @description_filter = resolve_register_description_filter
    @entry_form = AccountRegisterEntryForm.new(register_entry_params)

    if @entry_form.save
      session[:register_account_code] = @entry_form.account_code
      remember_register_recorded_on(@entry_form.recorded_on)
      redirect_to register_vouchers_path(
        account_code: @entry_form.account_code,
        description: @description_filter,
        anchor: "register-entry",
        focus_entry: "counterpart"
      ), notice: t("vouchers.flash.saved")
    else
      @account_code = @entry_form.account_code.presence || resolve_register_account
      prepare_register_view
      flash.now[:alert] = @entry_form.errors.full_messages.join(" / ")
      render :register, status: :unprocessable_entity
    end
  end

  def update_register_line
    load_accounts
    @description_filter = resolve_register_description_filter
    @edit_form = AccountRegisterLineUpdateForm.new(register_update_params.merge(line_id: params[:id]))

    if @edit_form.save
      session[:register_account_code] = @edit_form.account_code
      redirect_to register_vouchers_path(account_code: @edit_form.account_code, description: @description_filter, anchor: "line-#{params[:id]}"), notice: t("vouchers.flash.updated")
    else
      @account_code = @edit_form.account_code.presence || resolve_register_account
      @edit_line_id = params[:id].to_i
      prepare_register_view
      @entry_form = AccountRegisterEntryForm.new(account_code: @account_code, recorded_on: resolve_register_recorded_on)
      flash.now[:alert] = @edit_form.errors.full_messages.join(" / ")
      render :register, status: :unprocessable_entity
    end
  end

  def create_quick
    @form = QuickVoucherForm.new(**quick_params)
    load_accounts

    if @form.save
      store_quick_defaults
      redirect_to quick_vouchers_path, notice: t("vouchers.flash.saved")
    else
      prepare_quick_view
      flash.now[:alert] = @form.errors.full_messages.join(" / ")
      render :quick, status: :unprocessable_entity
    end
  end

  private

  def set_voucher
    @voucher = Voucher.includes(:voucher_lines).find(params[:id])
  end

  def voucher_params
    params.require(:voucher).permit(:recorded_on, :voucher_number, :description,
      voucher_lines_attributes: %i[id account_code account debit_amount credit_amount note _destroy])
  end

  def load_accounts
    @accounts = Account.order(:code)
    @editable_accounts = @accounts.reject(&:is_lock)
  end

  def quick_params
    params.require(:quick_voucher).permit(:recorded_on, :direction,
      :account_code_deposit, :counter_account_code_deposit,
      :account_code_withdrawal, :counter_account_code_withdrawal,
      :amount_deposit, :amount_withdrawal,
      :description_deposit, :description_withdrawal)
  end

  def register_entry_params
    params.require(:register_entry).permit(:account_code, :recorded_on, :description, :counterpart_code, :amount)
  end

  def register_update_params
    params.require(:register_update).permit(:account_code, :recorded_on, :description, :counterpart_code, :amount)
  end

  def prepare_quick_view
    @all_accounts_map = @accounts.index_by(&:code).transform_values(&:name)
    @accounts_map = @editable_accounts.index_by(&:code).transform_values(&:name)
    @recent_vouchers = Voucher.includes(:voucher_lines).order(created_at: :desc).limit(20)
  end

  def prepare_register_view
    @account = @accounts.find { |a| a.code == @account_code } || @accounts.first
    @account_code = @account&.code
    session[:register_account_code] = @account_code if @account_code.present?
    @accounts_map = @accounts.index_by(&:code).transform_values(&:name)
    @editable_accounts_map = @editable_accounts.index_by(&:code).transform_values(&:name)

    @register_rows = []
    @current_balance = 0.to_d
    return if @account.blank?

    lines = VoucherLine.includes(voucher: :voucher_lines)
                       .joins(:voucher)
                       .where(account_code: @account.code)
    if @description_filter.present?
      lines = lines.where("vouchers.description LIKE ?", "%#{@description_filter}%")
    end
    lines = lines.order("vouchers.recorded_on ASC, vouchers.id ASC, voucher_lines.id ASC")
    @register_rows = lines.map do |line|
      counterpart = line.voucher.voucher_lines.find { |row| row.id != line.id }
      signed_amount = line.debit_amount.to_d - line.credit_amount.to_d
      {
        line: line,
        voucher: line.voucher,
        counterpart_code: counterpart&.account_code,
        counterpart_name: @accounts_map[counterpart&.account_code],
        amount: signed_amount
      }
    end
    @register_rows.sort_by! do |row|
      [
        row[:voucher].recorded_on || Date.new(1900, 1, 1),
        row[:counterpart_code].to_s,
        row[:voucher].description.to_s,
        row[:voucher].id.to_i,
        row[:line].id.to_i
      ]
    end
    @current_balance = @register_rows.sum { |row| row[:amount].to_d }

    if @edit_line_id.present? && @edit_form.nil?
      row = @register_rows.find { |item| item[:line].id == @edit_line_id }
      if row
        @edit_form = AccountRegisterLineUpdateForm.new(
          line_id: row[:line].id,
          account_code: @account_code,
          recorded_on: row[:voucher].recorded_on,
          description: row[:voucher].description,
          counterpart_code: row[:counterpart_code],
          amount: row[:amount]
        )
      end
    end
  end

  def resolve_account_filter
    if params.key?(:account_code)
      if params[:account_code].present?
        session[:vouchers_account_code] = params[:account_code]
      else
        session.delete(:vouchers_account_code)
      end
      return params[:account_code].presence
    end

    session[:vouchers_account_code].presence
  end

  def resolve_description_filter
    if params.key?(:description)
      if params[:description].present?
        session[:vouchers_description] = params[:description]
      else
        session.delete(:vouchers_description)
      end
      return params[:description].presence
    end

    session[:vouchers_description].presence
  end

  def resolve_register_account
    if params.key?(:account_code)
      session[:register_account_code] = params[:account_code].presence
      return params[:account_code].presence
    end

    session[:register_account_code].presence
  end

  def resolve_register_description_filter
    if params.key?(:description)
      session[:register_description] = params[:description].presence
      return params[:description].presence
    end

    session[:register_description].presence
  end

  def resolve_register_recorded_on
    raw = session[:register_recorded_on].presence
    return Date.current if raw.blank?

    Date.parse(raw)
  rescue ArgumentError
    Date.current
  end

  def remember_register_recorded_on(value)
    return if value.blank?

    session[:register_recorded_on] = value.to_date.iso8601
  end

  def load_return_context
    @return_to = params[:return_to].presence
    @return_account_code = params[:return_account_code].presence
    @return_description = params[:return_description].presence
    @return_anchor = params[:return_anchor].presence
  end

  def voucher_update_redirect_path
    return vouchers_path unless @return_to == "register"

    opts = {}
    opts[:account_code] = @return_account_code if @return_account_code.present?
    opts[:description] = @return_description if @return_description.present?
    opts[:anchor] = @return_anchor if @return_anchor.present?
    register_vouchers_path(**opts)
  end

  def expand_account_codes(code)
    return nil if code.blank?
    codes = [code]
    queue = [code]
    while queue.any?
      current = queue.shift
      children = Account.where(parent_code: current).pluck(:code)
      queue.concat(children)
      codes.concat(children)
    end
    codes.uniq
  end

  def store_quick_defaults
    session[:quick_voucher_last] = quick_params.slice(
      :recorded_on,
      :account_code_deposit, :counter_account_code_deposit, :description_deposit,
      :account_code_withdrawal, :counter_account_code_withdrawal, :description_withdrawal
    ).to_h
  end

  def quick_defaults
    (session[:quick_voucher_last] || {}).symbolize_keys
  end
end
