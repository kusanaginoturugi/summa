class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :load_fiscal_year_context

  helper_method :current_fiscal_year, :current_fiscal_year_range, :fiscal_year_options

  private

  def load_fiscal_year_context
    @current_fiscal_year = safe_current_fiscal_year
    @fiscal_year_options = safe_fiscal_year_options(@current_fiscal_year)
  end

  def current_fiscal_year
    @current_fiscal_year
  end

  def current_fiscal_year_range
    Date.new(current_fiscal_year, 1, 1)..Date.new(current_fiscal_year, 12, 31)
  end

  def fiscal_year_options
    @fiscal_year_options
  end

  def safe_current_fiscal_year
    AppSetting.current_fiscal_year
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    Date.current.year
  end

  def safe_fiscal_year_options(default_year)
    AppSetting.available_fiscal_years(default_year: default_year)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    [default_year]
  end
end
