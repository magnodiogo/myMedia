class ArtistsController < ApplicationController
  before_action :set_artist, only: %i[ show edit update destroy update_wiki update_photo load_discography ]
  before_action :require_admin!, only: %i[ new create edit update destroy update_wiki update_photo load_discography ]
  before_action :resize_uploaded_images, only: %i[ create update ]

  def index
    @artists = Artist.with_attached_photo.all.order(:name)
  end

  def show
    @albums = @artist.albums.includes(media: { cover_image_attachment: :blob }).with_attached_cover_image.order(:release_year, :title)
    @albums_by_type = @albums.group_by(&:album_type)
    @media = @artist.media.includes(:album, :media_type).order(title: :asc)
    @collection_items = current_user.user_media.joins(:media).includes(media: [:album, :media_type, { cover_image_attachment: :blob }]).where(media: { artist_id: @artist.id }).order(created_at: :desc) if current_user
    @styles = @artist.albums.joins(:media_styles).distinct.order("media_styles.name").pluck("media_styles.name")
  end

  def new
    @artist = Artist.new
  end

  def edit
  end

  def create
    @artist = Artist.new(artist_params)
    if @artist.save
      redirect_to artists_path, notice: "Artist was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @artist.update(artist_params)
      redirect_to artists_path, notice: "Artist was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @artist.destroy
      redirect_to artists_path, notice: "Artist was successfully destroyed."
    else
      redirect_to artists_path, alert: @artist.errors.full_messages.to_sentence
    end
  end

  def update_wiki
    if @artist.update_bio_from_wikipedia
      redirect_to edit_artist_path(@artist), notice: "Artist biography successfully updated from Wikipedia."
    else
      redirect_to edit_artist_path(@artist), alert: "Could not find a Wikipedia biography for this artist."
    end
  end

  def update_photo
    if @artist.update_photo_from_wikipedia
      redirect_to edit_artist_path(@artist), notice: "Artist photo successfully updated from Wikipedia."
    else
      redirect_to edit_artist_path(@artist), alert: "Could not find a Wikipedia photo for this artist."
    end
  end

  def load_discography
    result = @artist.load_discography

    if result[:error].present?
      redirect_to artist_path(@artist), alert: result[:error]
    else
      redirect_to artist_path(@artist), notice: "Discography loaded: #{result[:imported]} imported, #{result[:updated]} updated, #{result[:skipped]} skipped."
    end
  end

  private

  def set_artist
    @artist = Artist.friendly.find(params[:id])
  end

  def artist_params
    params.require(:artist).permit(:name, :bio, :photo, :banner, :fun_facts)
  end

  def resize_uploaded_images
    if params.dig(:artist, :photo).present?
      uploaded_file = params[:artist][:photo]
      if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.present?
        system("mogrify -resize '600x600>' -strip #{uploaded_file.tempfile.path}")
      end
    end

    if params.dig(:artist, :banner).present?
      uploaded_file = params[:artist][:banner]
      if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.present?
        system("mogrify -resize '1600x>' -strip -quality 85 #{uploaded_file.tempfile.path}")
      end
    end
  end
end
