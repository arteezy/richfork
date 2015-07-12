class RatesController < ApplicationController
  before_action :authenticate_user!

  def create
    rate = Rate.where(user_id: current_user.id, album_id: params[:id])
    if rate.exists?
      rate.update(rate: params[:rate].to_f)
    else
      rate.create(rate: params[:rate].to_f)
    end
    render nothing: true
  end
end