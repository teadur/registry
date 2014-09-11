class Admin::DomainsController < ApplicationController
  before_action :set_domain, only: [:show]

  def new
    @domain = Domain.new
  end

  def create
    @domain = Domain.new({
      valid_from: Date.today,
      valid_to: Date.today + 1.year,
      registered_at: Time.zone.now
    }.merge(domain_params))

    if @domain.save
      redirect_to [:admin, @domain]
    else
      render 'new'
    end
  end

  def index
    @q = Domain.search(params[:q])
    @domains = @q.result.page(params[:page])
  end

  def show
    @domain.all_dependencies_valid?
  end

  private

  def set_domain
    @domain = Domain.find(params[:id])
  end

  def domain_params
    params.require(:domain).permit(:name, :period, :registrar_id, :owner_contact_id)
  end
end
