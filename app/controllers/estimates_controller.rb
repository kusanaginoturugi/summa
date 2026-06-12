class EstimatesController < ApplicationController
  before_action :set_estimate, only: %i[edit update pdf]

  def index
    @estimates = Estimate.includes(:estimate_items).order(issued_on: :desc, created_at: :desc)
  end

  def new
    @estimate = Estimate.new(
      estimate_number: next_estimate_number,
      issued_on: Date.current,
      valid_until: 1.month.from_now.to_date
    )
    @estimate.estimate_items.build
  end

  def create
    @estimate = Estimate.new(estimate_params)

    if @estimate.save
      redirect_to estimates_path, notice: "見積書を保存しました"
    else
      @estimate.estimate_items.build if @estimate.estimate_items.empty?
      flash.now[:alert] = @estimate.errors.full_messages.join(" / ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @estimate.update(estimate_params)
      redirect_to estimates_path, notice: "見積書を更新しました"
    else
      @estimate.estimate_items.build if @estimate.estimate_items.empty?
      flash.now[:alert] = @estimate.errors.full_messages.join(" / ")
      render :edit, status: :unprocessable_entity
    end
  end

  def pdf
    pdf = EstimatePdfService.new(@estimate).generate
    send_data pdf,
      filename: "#{@estimate.estimate_number}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  rescue EstimatePdfService::GenerationError => e
    redirect_to estimates_path, alert: e.message
  end

  private

  def set_estimate
    @estimate = Estimate.includes(:estimate_items).find(params[:id])
  end

  def estimate_params
    params.require(:estimate).permit(
      :estimate_number, :issued_on, :valid_until, :issuer, :recipient, :tax_rate, :note,
      estimate_items_attributes: %i[id description detail quantity unit_price position _destroy]
    )
  end

  def next_estimate_number
    prefix = "EST-#{Date.current.strftime('%Y%m%d')}"
    sequence = Estimate.where("estimate_number LIKE ?", "#{prefix}-%").count + 1
    format("%s-%03d", prefix, sequence)
  end
end
