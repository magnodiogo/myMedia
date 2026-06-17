require 'net/http'

module BarcodeAdapters
  class Base
    attr_reader :barcode

    def initialize(barcode)
      @barcode = barcode
    end

    def lookup
      raise NotImplementedError, "#{self.class.name} must implement #lookup"
    end

    protected

    def fetch_json(url, headers = {})
      uri = URI(url)
      req = Net::HTTP::Get.new(uri)
      headers.each { |key, value| req[key] = value }

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.request(req)
      end

      if response.code == '200'
        JSON.parse(response.body)
      else
        nil
      end
    rescue => e
      Rails.logger.error "[#{self.class.name}] Fetch failed: #{e.message}"
      nil
    end
  end
end
