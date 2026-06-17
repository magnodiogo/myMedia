class MediaTypesController < ApplicationController
  before_action :set_media_type, only: %i[ show edit update destroy ]

  def index
    @media_types = MediaType.all
  end

  def show
    @media = @media_type.media
  end

  def new
    @media_type = MediaType.new
  end

  def edit
  end

  def create
    @media_type = MediaType.new(media_type_params)
    if @media_type.save
      redirect_to media_types_path, notice: "Media type was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @media_type.update(media_type_params)
      redirect_to media_types_path, notice: "Media type was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @media_type.destroy
      redirect_to media_types_path, notice: "Media type was successfully destroyed."
    else
      redirect_to media_types_path, alert: @media_type.errors.full_messages.to_sentence
    end
  end

  private

  def set_media_type
    @media_type = MediaType.find(params[:id])
  end

  def media_type_params
    params.require(:media_type).permit(:name, :description)
  end
end
