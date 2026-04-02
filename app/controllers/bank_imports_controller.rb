class BankImportsController < ApplicationController
  def new
    @accounts = Account.order(:code)
    @input_accounts = @accounts.reject(&:is_lock)
    @settings = BankImportSetting.order(:name)
    @form = BankCsvImportForm.new(default_params)

    setting_id = selected_setting_id_for_new
    return if setting_id.blank?

    setting = @settings.find_by(id: setting_id)
    if setting
      @form = BankCsvImportForm.new(default_params.merge(setting_params(setting)))
      session[:last_bank_import_setting_id] = setting.id
    else
      session.delete(:last_bank_import_setting_id)
    end
  end

  def create
    @accounts = Account.order(:code)
    @input_accounts = @accounts.reject(&:is_lock)
    @settings = BankImportSetting.order(:name)
    permitted = import_params
    remember_selected_setting(permitted[:setting_id])
    @form = BankCsvImportForm.new(permitted)

    if params[:preview].present?
      if @form.parse_only
        @preview_token = store_preview_rows(@form.rows_json)
        render :preview, status: :ok
      else
        flash.now[:alert] = @form.errors.full_messages.join(" / ")
        render :new, status: :unprocessable_entity
      end
      return
    end

    rows_json = load_preview_rows(params[:bank_import_preview_token])
    if rows_json.blank?
      flash.now[:alert] = t("bank_imports.errors.preview_expired")
      render :new, status: :unprocessable_entity
      return
    end
    @form = BankCsvImportForm.new(permitted.except(:rows).merge(rows: rows_json))

    if @form.save
      notice = t("bank_imports.flash.imported", count: @form.created_count)
      notice += " " + t("bank_imports.flash.skipped", count: @form.skipped_rows.size) if @form.skipped_rows.present?
      redirect_to register_vouchers_path(account_code: @form.bank_account_code), notice: notice
    else
      flash.now[:alert] = @form.errors.full_messages.join(" / ")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def import_params
    params.require(:bank_csv_import_form).permit(
      :file, :bank_account_code, :deposit_counter_code, :withdrawal_counter_code,
      :date_column, :description_column, :deposit_column, :withdrawal_column,
      :setting_id, :setting_name, :save_setting, :has_header
    )
  end

  PREVIEW_CACHE_TTL = 30.minutes

  def store_preview_rows(rows_json)
    token = SecureRandom.hex(16)
    Rails.cache.write("bank_import_preview:#{token}", rows_json, expires_in: PREVIEW_CACHE_TTL)
    token
  end

  def load_preview_rows(token)
    return nil if token.blank?

    Rails.cache.fetch("bank_import_preview:#{token}").tap do
      Rails.cache.delete("bank_import_preview:#{token}")
    end
  end

  def default_params
    {
      bank_account_code: "102",
      deposit_counter_code: "401",
      withdrawal_counter_code: "520",
      date_column: "日付",
      description_column: "摘要",
      deposit_column: "入金額",
      withdrawal_column: "出金額",
      has_header: true
    }
  end

  def setting_params(setting)
    setting.slice(
      :bank_account_code, :deposit_counter_code, :withdrawal_counter_code,
      :date_column, :description_column, :deposit_column, :withdrawal_column, :has_header
    ).merge(setting_id: setting.id, setting_name: setting.name)
  end

  def selected_setting_id_for_new
    if params.key?(:setting_id)
      setting_id = params[:setting_id].presence
      session[:last_bank_import_setting_id] = setting_id if setting_id.present?
      session.delete(:last_bank_import_setting_id) if setting_id.blank?
      return setting_id
    end

    session[:last_bank_import_setting_id].presence
  end

  def remember_selected_setting(setting_id)
    if setting_id.present? && @settings.exists?(id: setting_id)
      session[:last_bank_import_setting_id] = setting_id.to_i
    else
      session.delete(:last_bank_import_setting_id)
    end
  end
end
