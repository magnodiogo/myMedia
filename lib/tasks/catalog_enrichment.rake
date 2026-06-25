namespace :catalog do
  namespace :enrich do
    desc "Load discographies, album metadata, AllMusic album data, and credit person data"
    task all: :environment do
      processor = CatalogEnrichmentTask.new(
        dry_run: ENV["DRY_RUN"].to_s == "1",
        limit: ENV["LIMIT"].presence&.to_i,
        artist_id: ENV["ARTIST_ID"].presence,
        artist_slug: ENV["ARTIST_SLUG"].presence,
        sleep_seconds: ENV.fetch("SLEEP", "0.5").to_f
      )

      processor.run
    end
  end
end

class CatalogEnrichmentTask
  def initialize(dry_run:, limit:, artist_id:, artist_slug:, sleep_seconds:)
    @dry_run = dry_run
    @limit = limit
    @artist_id = artist_id
    @artist_slug = artist_slug
    @sleep_seconds = sleep_seconds
    @stats = Hash.new(0)
  end

  def run
    say "Starting catalog enrichment#{dry_run? ? ' (dry run)' : ''}."
    say "Scope: #{artist_scope_description}"

    process_artists
    process_credit_people
    print_summary
  end

  private

  def process_artists
    artists.find_each do |artist|
      @stats[:artists_seen] += 1
      say "\nArtist: #{artist.name}"

      load_artist_discography(artist)
      load_artist_albums(artist)
    end
  end

  def load_artist_discography(artist)
    if dry_run?
      say "  Discography: would load"
      return
    end

    result = artist.load_discography
    if result[:error].present?
      @stats[:artist_discography_errors] += 1
      say "  Discography: error - #{result[:error]}"
    else
      @stats[:artist_discographies_loaded] += 1
      @stats[:albums_imported_from_discography] += result[:imported].to_i
      @stats[:albums_updated_from_discography] += result[:updated].to_i
      @stats[:albums_skipped_from_discography] += result[:skipped].to_i
      say "  Discography: #{result[:imported]} imported, #{result[:updated]} updated, #{result[:skipped]} skipped"
    end
  rescue => e
    @stats[:artist_discography_errors] += 1
    say "  Discography: error - #{e.class}: #{e.message}"
  ensure
    pause
  end

  def load_artist_albums(artist)
    artist.albums.order(:release_year, :title).find_each do |album|
      @stats[:albums_seen] += 1
      say "  Album: #{album.title}"

      if dry_run?
        say "    Metadata: would load"
        say "    AllMusic: would import#{album.allmusic_url.present? ? " from #{album.allmusic_url}" : ' after search'}"
        next
      end

      load_album_metadata(album)
      load_album_allmusic(album)
      pause
    end
  end

  def load_album_metadata(album)
    result = AlbumEnrichmentService.new(album).perform
    if result[:error].present?
      @stats[:album_metadata_errors] += 1
      say "    Metadata: error - #{result[:error]}"
    else
      @stats[:album_metadata_loaded] += 1
      @stats[:tracks_imported] += result[:imported_tracks].to_i
      @stats[:tracks_updated] += result[:updated_tracks].to_i
      @stats[:lyrics_found] += result[:lyrics_found].to_i
      say "    Metadata: #{result[:imported_tracks]} tracks imported, #{result[:updated_tracks]} updated, #{result[:lyrics_found]} lyrics found"
    end
  rescue => e
    @stats[:album_metadata_errors] += 1
    say "    Metadata: error - #{e.class}: #{e.message}"
  end

  def load_album_allmusic(album)
    result = album.import_allmusic!
    if result[:skipped]
      @stats[:album_allmusic_skipped] += 1
      say "    AllMusic: skipped - #{result[:error]}"
    elsif result[:success]
      @stats[:album_allmusic_loaded] += 1
      @stats[:album_allmusic_credits] += result[:credits].size
      say "    AllMusic: #{result[:credits].size} credits imported"
    else
      @stats[:album_allmusic_errors] += 1
      say "    AllMusic: error - #{result[:error]}"
    end
  rescue => e
    @stats[:album_allmusic_errors] += 1
    say "    AllMusic: error - #{e.class}: #{e.message}"
  end

  def process_credit_people
    say "\nCredit people"

    CreditPerson.order(:name).find_each do |person|
      @stats[:credit_people_seen] += 1

      if dry_run?
        say "  #{person.name}: would load"
        next
      end

      result = person.load_external_data
      if result[:bio] || result[:photo] || result[:wikipedia_bio] || result[:allmusic]
        @stats[:credit_people_loaded] += 1
        say "  #{person.name}: loaded"
      else
        @stats[:credit_people_skipped] += 1
        error_text = result[:errors].present? ? " - #{result[:errors].join('; ')}" : ""
        say "  #{person.name}: no new data#{error_text}"
      end
    rescue => e
      @stats[:credit_people_errors] += 1
      say "  #{person.name}: error - #{e.class}: #{e.message}"
    ensure
      pause
    end
  end

  def artists
    scope = Artist.order(:name)
    scope = scope.where(id: @artist_id) if @artist_id.present?
    scope = scope.where(id: Artist.friendly.find(@artist_slug).id) if @artist_slug.present?
    scope = scope.limit(@limit) if @limit.present? && @limit.positive?
    scope
  end

  def artist_scope_description
    return "artist id #{@artist_id}" if @artist_id.present?
    return "artist slug #{@artist_slug}" if @artist_slug.present?
    return "first #{@limit} artists" if @limit.present? && @limit.positive?

    "all artists"
  end

  def print_summary
    say "\nSummary"
    @stats.keys.sort.each do |key|
      say "  #{key}: #{@stats[key]}"
    end
  end

  def dry_run?
    @dry_run
  end

  def pause
    sleep @sleep_seconds if @sleep_seconds.positive?
  end

  def say(message)
    puts message
    Rails.logger.info("[CatalogEnrichmentTask] #{message}")
  end
end
