module BarcodeAdapters
  class Musicbrainz < Base
    def lookup
      url = "https://musicbrainz.org/ws/2/release/?query=barcode:#{barcode}&fmt=json"
      headers = { "User-Agent" => "myMediaCataloger/1.0.0 (magno@example.com)" }
      data = fetch_json(url, headers)
      return nil unless data && data["releases"] && data["releases"].any?

      release = data["releases"].first
      artist = release["artist-credit"]&.map { |ac| ac["name"] }&.join(", ")
      catalog = release["label-info"]&.first&.dig("catalog-number")
      
      # Check Cover Art Archive for cover
      cover_url = check_cover_art_archive(release["id"])

      {
        source: "MusicBrainz",
        title: release["title"],
        artist: artist,
        year: release["date"]&.slice(0, 4),
        catalog: catalog,
        cover_url: cover_url
      }
    end

    private

    def check_cover_art_archive(release_id)
      caa_uri = URI("https://coverartarchive.org/release/#{release_id}/front")
      begin
        caa_check = Net::HTTP.start(caa_uri.hostname, caa_uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
          http.request_head(caa_uri.path)
        end
        if caa_check.code == '200' || caa_check.code == '307' || caa_check.code == '302'
          caa_uri.to_s
        end
      rescue => e
        Rails.logger.warn "[BarcodeAdapters::Musicbrainz] CAA check failed: #{e.message}"
        nil
      end
    end
  end
end
