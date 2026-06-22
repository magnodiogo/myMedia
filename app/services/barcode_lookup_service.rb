class BarcodeLookupService
  # Add new adapters to this list to support more APIs in the future
  ADAPTERS = [
    BarcodeAdapters::Itunes,
    BarcodeAdapters::Discogs,
    BarcodeAdapters::Musicbrainz
  ]

  def self.lookup(barcode)
    ADAPTERS.each do |adapter_class|
      begin
        result = adapter_class.new(barcode).lookup
        return result if result.present?
      rescue => e
        Rails.logger.error "[BarcodeLookupService] #{adapter_class.name} failed: #{e.message}"
      end
    end
    nil
  end
end
