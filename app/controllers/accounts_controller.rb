class AccountsController < ApplicationController
  before_action :load_accounts, only: %i[index new edit]
  before_action :set_account, only: %i[edit update destroy]

  def index
  end

  def new
    @account = Account.new
  end

  def summary
    @lock_filter = normalize_lock_filter(params[:lock_filter])
    from = ActiveRecord::Base.connection.quote(current_fiscal_year_range.begin)
    to = ActiveRecord::Base.connection.quote(current_fiscal_year_range.end)
    join_sql = <<~SQL.squish
      LEFT JOIN (
        SELECT voucher_lines.account_code AS account_code,
               SUM(voucher_lines.debit_amount - voucher_lines.credit_amount) AS total_amount,
               COUNT(*) AS entry_count
        FROM voucher_lines
        INNER JOIN vouchers ON vouchers.id = voucher_lines.voucher_id
        WHERE vouchers.recorded_on BETWEEN #{from} AND #{to}
        GROUP BY voucher_lines.account_code
      ) fiscal_totals ON fiscal_totals.account_code = accounts.code
    SQL

    scope = Account.joins(join_sql)
                   .select(
                     "accounts.code, accounts.name, accounts.category, accounts.is_lock, " \
                     "COALESCE(fiscal_totals.total_amount, 0) AS total_amount, " \
                     "COALESCE(fiscal_totals.entry_count, 0) AS entry_count"
                   )
                   .where("COALESCE(fiscal_totals.entry_count, 0) > 0")
                   .order(:code)

    case @lock_filter
    when "locked"
      scope = scope.where(accounts: { is_lock: true })
    when "unlocked"
      scope = scope.where(accounts: { is_lock: false })
    end

    @summaries = scope
  end

  def create
    @account = Account.new(account_params)
    if @account.save
      redirect_to new_account_path, notice: t("accounts.flash.created")
    else
      load_accounts
      flash.now[:alert] = @account.errors.full_messages.join(" / ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: t("accounts.flash.updated")
    else
      load_accounts
      flash.now[:alert] = @account.errors.full_messages.join(" / ")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    if @account.destroy
      redirect_to accounts_path, notice: t("accounts.flash.deleted")
    else
      load_accounts
      flash.now[:alert] = @account.errors.full_messages.join(" / ")
      render :index, status: :unprocessable_entity
    end
  end

  def entries
    @account = Account.find(params[:id])
    codes = [@account.code] + descendant_codes(@account)
    @included_codes = codes
    @lines = VoucherLine.includes(:voucher, :account_master)
                        .joins(:voucher)
                        .where(account_code: codes)
                        .where(vouchers: { recorded_on: current_fiscal_year_range })
                        .order("vouchers.recorded_on ASC, vouchers.id ASC, voucher_lines.id ASC")
    @accounts_map = Account.pluck(:code, :name).to_h
    @editable_accounts_map = Account.unlocked.order(:code).pluck(:code, :name).to_h
    @account_categories = Account.pluck(:code, :category).to_h
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def load_accounts
    @accounts = Account.order(:category, :code)
  end

  def descendant_codes(account)
    codes = []
    queue = [account]
    while queue.any?
      parent = queue.shift
      children = Account.where(parent_code: parent.code)
      codes.concat(children.pluck(:code))
      queue.concat(children)
    end
    codes
  end

  def account_params
    params.require(:account).permit(:code, :name, :details, :category, :parent_code, :is_lock)
  end

  def normalize_lock_filter(value)
    return value if %w[all locked unlocked].include?(value)

    "all"
  end
end
