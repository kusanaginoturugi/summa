class AccountsController < ApplicationController
  before_action :load_accounts, only: %i[index new edit]
  before_action :set_account, only: %i[edit update destroy]

  def index
  end

  def new
    @account = Account.new
  end

  def summary
    @summaries = Account.left_joins(:voucher_lines)
                        .select(
                          "accounts.code, accounts.name, accounts.category, " \
                          "COALESCE(SUM(voucher_lines.debit_amount - voucher_lines.credit_amount), 0) AS total_amount, " \
                          "COUNT(voucher_lines.id) AS entry_count"
                        )
                        .group("accounts.code, accounts.name, accounts.category")
                        .having("ABS(COALESCE(SUM(voucher_lines.debit_amount - voucher_lines.credit_amount), 0)) > 0")
                        .order(:code)
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
                        .where(account_code: codes)
                        .order("vouchers.recorded_on ASC, vouchers.id ASC, voucher_lines.id ASC")
    @accounts_map = Account.pluck(:code, :name).to_h
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
    params.require(:account).permit(:code, :name, :details, :category, :parent_code)
  end
end
