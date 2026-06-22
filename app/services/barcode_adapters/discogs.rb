module BarcodeAdapters
  class Discogs < Base
    def lookup
      token = ENV["DISCOGS_TOKEN"] || "TPfEJXlWcimuwWmFvvENlMGtyHbvJtqhsSzbpjuX"
      url = "https://api.discogs.com/database/search?barcode=#{barcode}&type=release"
      headers = {
        "Authorization" => "Discogs Token #{token}",
        "User-Agent" => "ColecaoCDs/1.0"
      }
      data = fetch_json(url, headers)
      return nil unless data && data["results"] && data["results"].any?

      release = data["results"].first
      title_parts = release["title"].to_s.split(" - ", 2)
      artist = title_parts.first&.strip
      title = title_parts.last&.strip || release["title"]

      cover_url = release["cover_image"].presence || release["thumb"].presence
      if cover_url.blank? && release["id"].present?
        release_details = fetch_json("https://api.discogs.com/releases/#{release["id"]}", headers)
        if release_details && release_details["images"]&.any?
          cover_url = release_details["images"].first["uri"] || release_details["images"].first["resource_url"]
        end
        cover_url ||= release_details["thumb"].presence || release_details["cover_image"].presence if release_details
      end

      {
        source: "Discogs",
        title: title,
        artist: artist,
        year: release["year"],
        catalog: release["catno"],
        cover_url: cover_url
      }
    end
  end
end
