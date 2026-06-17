module BarcodeAdapters
  class Itunes < Base
    def lookup
      url = "https://itunes.apple.com/lookup?upc=#{barcode}"
      data = fetch_json(url)
      return nil unless data && data["results"] && data["results"].any?

      album = data["results"].first
      {
        source: "iTunes",
        title: album["collectionName"],
        artist: album["artistName"],
        year: album["releaseDate"]&.slice(0, 4),
        catalog: nil,
        cover_url: album["artworkUrl100"]&.gsub("100x100bb", "600x600bb")
      }
    end
  end
end
