class AppSettingsController < ApplicationController
  def fiscal_year
    year = params[:fiscal_year].to_i
    if year <= 0
      redirect_to safe_return_path, alert: t("app_settings.fiscal_year.invalid")
      return
    end

    AppSetting.current_fiscal_year = year
    redirect_to safe_return_path, notice: t("app_settings.fiscal_year.updated", year: year)
  rescue ActiveRecord::RecordInvalid, ArgumentError
    redirect_to safe_return_path, alert: t("app_settings.fiscal_year.invalid")
  end

  private

  def safe_return_path
    path = params[:return_to].to_s
    return root_path if path.blank?
    return root_path unless path.start_with?("/")

    path
  end
end
