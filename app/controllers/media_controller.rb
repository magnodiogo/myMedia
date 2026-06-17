class MediaController < ApplicationController
  before_action :set_media, only: %i[ show edit update destroy ]
  before_action :resize_uploaded_cover, only: %i[ create update ]

  def index
    @query = params[:search]
    if @query.present?
      @media = Media.includes(:media_type).where("title LIKE ? OR artist LIKE ?", "%#{@query}%", "%#{@query}%").order(created_at: :desc)
    else
      @media = Media.includes(:media_type).order(created_at: :desc)
    end
  end

  def show
  end

  def new
    @media = Media.new
  end

  def edit
  end

  def create
    @media = Media.new(media_params)
    if @media.save
      redirect_to media_index_path, notice: "Media was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @media.update(media_params)
      redirect_to media_path(@media), notice: "Media was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @media.destroy
    redirect_to media_index_path, notice: "Media was successfully destroyed."
  end

  private

  def set_media
    @media = Media.find(params[:id])
  end

  def resize_uploaded_cover
    if params.dig(:media, :cover_image).present?
      uploaded_file = params[:media][:cover_image]
      if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.present?
        # Resize cover image to max 600x600 and strip metadata to save disk space
        system("mogrify -resize '600x600>' -strip #{uploaded_file.tempfile.path}")
      end
    end
  end

  def media_params
    params.require(:media).permit(:media_type_id, :title, :artist, :release_year, :catalog_number, :barcode, :notes, :cover_image, :cover_url)
  end
end
