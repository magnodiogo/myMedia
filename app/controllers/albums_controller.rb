class AlbumsController < ApplicationController
  before_action :set_album, only: %i[ show load_metadata ]
  before_action :require_admin!, only: %i[ load_metadata ]

  def show
    @album = Album.includes(:artist, :tracks, media: [:media_type, :user_media]).friendly.find(params[:id])
    @canonical_media = @album.canonical_media
    @tracks = @album.display_tracks
    @participant_credits = @album.participant_credits
    @user_media = current_user.user_media.includes(media: [:media_type, { cover_image_attachment: :blob }]).joins(:media).where(media: { album_id: @album.id }).order(created_at: :desc) if current_user
  end

  def load_metadata
    result = AlbumEnrichmentService.new(@album).perform

    if result[:error].present?
      redirect_to album_path(@album), alert: result[:error]
    else
      allmusic_result = import_allmusic_for_album
      notice = "Album data loaded. Tracks imported: #{result[:imported_tracks]}, tracks updated: #{result[:updated_tracks]}, lyrics found: #{result[:lyrics_found]}."
      notice += " AllMusic credits imported: #{allmusic_result[:credits].size}." if allmusic_result && !allmusic_result[:skipped] && allmusic_result[:success]
      notice += " AllMusic import failed: #{allmusic_result[:error]}." if allmusic_result && !allmusic_result[:skipped] && !allmusic_result[:success]

      redirect_to album_path(@album), notice: notice
    end
  end

  private

  def set_album
    @album = Album.friendly.find(params[:id])
  end

  def import_allmusic_for_album
    medium = @album.media.where.not(allmusic_url: [nil, ""]).first || @album.canonical_media
    medium&.import_allmusic!
  end
end
