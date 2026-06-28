require 'net/http'

class MediaController < ApplicationController
  before_action :set_media, only: %i[ show edit update destroy refresh_metadata ]
  before_action :resize_uploaded_cover, only: %i[ create update ]
  before_action :require_admin!, only: %i[ edit update destroy ]

  def index
    @query = params[:search]
    if @query.present?
      @media = current_user.media.includes(:album, :media_type, :artist).left_outer_joins(:artist).where("media.title ILIKE ? OR artists.name ILIKE ?", "%#{@query}%", "%#{@query}%").order(created_at: :desc)
    else
      @media = current_user.media.includes(:album, :media_type, :artist).order(created_at: :desc)
    end
  end

  def barcode_lookup
    barcode = params[:barcode].to_s.gsub(/[-\s]/, "")
    if barcode.blank?
      render json: { error: "Barcode is required" }, status: :bad_request
      return
    end

    result = BarcodeLookupService.lookup(barcode)

    if result
      render json: result
    else
      render json: { error: "Barcode not found online" }, status: :not_found
    end
  end


  def show
    @media = Media.includes(
      :album_release,
      :media_type,
      :artist,
      album: [:media_genres, :media_styles, :recording_locations, { album_credits: :credit_person }, { tracks: :track_credits }],
      album_credits: :credit_person,
      tracks: :track_credits
    ).friendly.find(params[:id])
    @album_record = @media.album
    @display_tracks = @album_record&.display_tracks.presence || @media.tracks.includes(:track_credits)
    @display_credits = @album_record&.album_credits || @media.album_credits
    @album_credits_by_category = @display_credits.includes(:credit_person).order(:person_name, :role).group_by(&:credit_category)
    @display_cover = @media.cover_image.attached? ? @media.cover_image : (@media.album_release&.display_cover || @album_record&.cover_image)
    @user_media = current_user.user_media.find_or_initialize_by(media: @media) if current_user
  end

  def new
    @media = Media.new
  end

  def edit
  end

  def create
    @media = Media.new(media_params)
    if @media.save
      UserMedia.create!(user: current_user, media: @media, notes: params.dig(:media, :notes))
      redirect_to media_index_path, notice: "Media was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def global_search
    title = params[:title].to_s.strip
    artist = params[:artist].to_s.strip

    if title.blank? && artist.blank?
      render json: { error: "Please enter a title or artist to search" }, status: :bad_request
      return
    end

    results = []

    # 1. Search Local Catalog Database
    local_query = Media.includes(:media_type, :artist).left_outer_joins(:artist)
    if title.present?
      local_query = local_query.where("media.title ILIKE ?", "%#{title}%")
    end
    if artist.present?
      local_query = local_query.where("artists.name ILIKE ?", "%#{artist}%")
    end

    local_query.limit(20).each do |m|
      results << {
        id: m.id,
        title: m.title,
        artist: m.artist&.name,
        format: m.media_type.name,
        release_year: m.release_year,
        cover_url: m.cover_image.attached? ? url_for(m.cover_image) : nil,
        source: "Local Catalog",
        owned: current_user.media.include?(m)
      }
    end

    # 2. Search Online (iTunes)
    search_term = [artist, title].reject(&:blank?).join(" ")
    itunes_uri = URI("https://itunes.apple.com/search?term=#{ERB::Util.url_encode(search_term)}&entity=album&limit=30")
    begin
      itunes_response = Net::HTTP.start(itunes_uri.hostname, itunes_uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.get(itunes_uri.request_uri)
      end

      if itunes_response.code == '200'
        itunes_data = JSON.parse(itunes_response.body)
        (itunes_data["results"] || []).each do |album|
          # Skip duplicate online matches
          next if results.any? { |r| r[:title].downcase == album["collectionName"].to_s.downcase && r[:artist].downcase == album["artistName"].to_s.downcase }
          
          results << {
            id: nil,
            title: album["collectionName"],
            artist: album["artistName"],
            format: "Online Album",
            release_year: album["releaseDate"]&.slice(0, 4),
            cover_url: album["artworkUrl100"]&.gsub("100x100bb", "600x600bb"),
            source: "iTunes Store",
            owned: false
          }
        end
      end
    rescue => e
      logger.error "iTunes Search failed: #{e.message}"
    end

    render json: results
  end

  def add_to_collection
    @media = Media.friendly.find(params[:id])
    if current_user.media.include?(@media)
      render json: { error: "Already in collection" }, status: :unprocessable_entity
    else
      UserMedia.create!(user: current_user, media: @media, notes: params[:notes])
      render json: { success: true }
    end
  end

  def import_and_add
    format_id = params[:media_type_id] || MediaType.first&.id
    
    @media = Media.new(
      media_type_id: format_id,
      title: params[:title],
      artist: params[:artist],
      release_year: params[:release_year],
      catalog_number: params[:catalog_number],
      barcode: params[:barcode],
      cover_url: params[:cover_url]
    )

    if @media.save
      UserMedia.create!(user: current_user, media: @media, notes: params[:notes])
      render json: { success: true }
    else
      render json: { error: @media.errors.full_messages.join(", ") }, status: :unprocessable_entity
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

  def refresh_metadata
    MediaEnrichmentService.new(@media).perform

    notice = "Media information is being updated."

    redirect_to @media, notice: notice
  end

  private

  def set_media
    @media = Media.friendly.find(params[:id])
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
    params.require(:media).permit(:media_type_id, :title, :artist, :release_year, :catalog_number, :barcode, :allmusic_url, :notes, :cover_image, :cover_url)
  end

  def import_allmusic_metadata
    return nil if @media.allmusic_url.blank?

    @media.album.update!(allmusic_url: @media.allmusic_url) if @media.album.present? && @media.album.allmusic_url.blank?
    @media.album&.import_allmusic! || @media.import_allmusic!
  end
end
