class BankImportsController < ApplicationController
  def new
    @accounts = Account.order(:code)
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
    @settings = BankImportSetting.order(:name)
    permitted = import_params
    remember_selected_setting(permitted[:setting_id])
    @form = BankCsvImportForm.new(permitted)

    if params[:preview].present?
      if @form.parse_only
        render :preview, status: :ok
      else
        flash.now[:alert] = @form.errors.full_messages.join(" / ")
        render :new, status: :unprocessable_entity
      end
      return
    end

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
      :setting_id, :setting_name, :save_setting, :has_header, :rows
    )
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
