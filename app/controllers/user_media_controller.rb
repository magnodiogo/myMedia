class UserMediaController < ApplicationController
  before_action :set_user_media, only: %i[ update ]

  def create
    @user_media = current_user.user_media.build(user_media_params)

    if @user_media.save
      redirect_to media_path(@user_media.media), notice: "Added to your collection."
    else
      redirect_to media_path(@user_media.media || params[:user_media][:media_id]), alert: "Failed to add to collection."
    end
  end

  def update
    if @user_media.update(user_media_params)
      redirect_to media_path(@user_media.media), notice: "Collection details updated."
    else
      redirect_to media_path(@user_media.media), alert: "Failed to update collection details."
    end
  end

  private

  def set_user_media
    @user_media = current_user.user_media.find(params[:id])
  end

  def user_media_params
    params.require(:user_media).permit(
      :media_id, :notes, :purchase_location, :price_paid, :currency,
      :purchase_date, :physical_location, :condition, :sleeve_condition,
      :is_signed, :is_sealed, :edition_notes
    )
  end
end
