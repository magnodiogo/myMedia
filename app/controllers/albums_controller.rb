class AlbumsController < ApplicationController
  before_action :set_album, only: %i[ show load_metadata update_allmusic_url edit update try_load_cover ]
  before_action :require_admin!, only: %i[ load_metadata update_allmusic_url edit update try_load_cover ]
  before_action :resize_uploaded_cover, only: %i[ update ]

  def show
    @album = Album.includes(:artist, :media_genres, :media_styles, :recording_locations, album_credits: :credit_person, tracks: :track_credits, media: [:media_type, :user_media]).friendly.find(params[:id])
    @canonical_media = @album.canonical_media
    @tracks = @album.display_tracks
    @album_releases = @album.album_releases.includes(:media_type).with_attached_cover_image
    @owned_album_release_ids = current_user ? current_user.media.where(album: @album).where.not(album_release_id: nil).pluck(:album_release_id) : []
    @album_credits_by_category = @album.album_credits.includes(:credit_person).order(:person_name, :role).group_by(&:credit_category)
    @participant_credits = @album.participant_credits
    @user_media = current_user.user_media.includes(media: [:media_type, { cover_image_attachment: :blob }]).joins(:media).where(media: { album_id: @album.id }).order(created_at: :desc) if current_user
  end

  def edit
    build_album_release_rows
  end

  def update
    if @album.update(album_params)
      redirect_to album_path(@album), notice: "Album was successfully updated."
    else
      build_album_release_rows
      render :edit, status: :unprocessable_entity
    end
  end

  def load_metadata
    result = AlbumEnrichmentService.new(@album).perform

    if result[:error].present?
      redirect_to album_path(@album), alert: result[:error]
    else
      notice = "Album data loaded. Tracks imported: #{result[:imported_tracks]}, tracks updated: #{result[:updated_tracks]}, lyrics found: #{result[:lyrics_found]}."

      redirect_to album_path(@album), notice: notice
    end
  end

  def try_load_cover
    if @album.try_load_cover!
      redirect_to album_path(@album), notice: "Album cover loaded successfully."
    else
      redirect_to album_path(@album), alert: "Could not find a cover on the internet for this album."
    end
  end

  def update_allmusic_url
    if @album.update(album_allmusic_params)
      redirect_to album_path(@album), notice: "AllMusic album link saved."
    else
      redirect_to album_path(@album), alert: @album.errors.full_messages.to_sentence
    end
  end

  private

  def set_album
    @album = Album.friendly.find(params[:id])
  end

  def sync_album_allmusic_url
    return if @album.allmusic_url.present?

    allmusic_url = @album.media.where.not(allmusic_url: [nil, ""]).pick(:allmusic_url)
    @album.update!(allmusic_url: allmusic_url) if allmusic_url.present?
  end

  def album_allmusic_params
    params.require(:album).permit(:allmusic_url)
  end

  def album_params
    params.require(:album).permit(
      :title, :release_year, :original_release_date, :album_type,
      :formatted_duration, :summary, :allmusic_url,
      :genre_names, :style_names, :recording_location_names,
      :cover_image, :manual_credits_text, :metadata_status, :fun_facts,
      album_releases_attributes: [
        :id, :title, :release_year, :media_type_id, :label, :catalog_number,
        :allmusic_url, :info, :position, :cover_image, :_destroy
      ]
    )
  end

  def build_album_release_rows
    blanks_needed = [3 - @album.album_releases.reject(&:persisted?).size, 0].max
    blanks_needed.times { @album.album_releases.build(position: @album.album_releases.size) }
  end

  def resize_uploaded_cover
    if params.dig(:album, :cover_image).present?
      uploaded_file = params[:album][:cover_image]
      if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.present?
        system("mogrify -resize '600x600>' -strip #{uploaded_file.tempfile.path}")
      end
    end
  end
end
