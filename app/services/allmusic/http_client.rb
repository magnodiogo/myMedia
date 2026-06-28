require "net/http"
require "uri"
require "openssl"

module Allmusic
  class HttpClient
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    CLOUDFLARE_CHALLENGE_ERROR = "AllMusic blocked automated access with a Cloudflare challenge".freeze

    def self.get(url, redirects: 3)
      raise "Too many redirects while downloading AllMusic page" if redirects.negative?

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 20
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
      request["Accept-Language"] = "en-US,en;q=0.9"
      request["Cache-Control"] = "no-cache"
      request["DNT"] = "1"
      request["Connection"] = "keep-alive"
      request["Referer"] = "https://www.allmusic.com/"
      request["Upgrade-Insecure-Requests"] = "1"
      request["Sec-CH-UA"] = "\"Google Chrome\";v=\"126\", \"Chromium\";v=\"126\", \"Not/A)Brand\";v=\"8\""
      request["Sec-CH-UA-Mobile"] = "?0"
      request["Sec-CH-UA-Platform"] = "\"macOS\""
      request["Sec-Fetch-Dest"] = "document"
      request["Sec-Fetch-Mode"] = "navigate"
      request["Sec-Fetch-Site"] = "same-origin"
      request["Sec-Fetch-User"] = "?1"

      response = http.request(request)
      raise CLOUDFLARE_CHALLENGE_ERROR if cloudflare_challenge?(response)

      if response.is_a?(Net::HTTPRedirection)
        location = response["location"]
        raise "AllMusic redirect did not include a location" if location.blank?
        return get(URI.join(uri, location).to_s, redirects: redirects - 1)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "AllMusic request failed with HTTP #{response.code}"
      end

      response.body.to_s
    end

    def self.cloudflare_challenge?(response)
      response["cf-mitigated"].to_s == "challenge" ||
        response.body.to_s.include?("challenges.cloudflare.com") ||
        response.body.to_s.include?("<title>Just a moment...</title>")
    end
    private_class_method :cloudflare_challenge?
  end
end
