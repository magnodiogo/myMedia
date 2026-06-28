require "test_helper"

class AllmusicHttpClientTest < ActiveSupport::TestCase
  test "raises a clear error when allmusic returns a cloudflare challenge" do
    response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    response["cf-mitigated"] = "challenge"
    response.body = "<html><head><title>Just a moment...</title></head></html>"

    fake_http = Struct.new(:response) do
      attr_accessor :use_ssl, :open_timeout, :read_timeout, :verify_mode

      def use_ssl?
        use_ssl
      end

      def request(_request)
        response
      end
    end

    original_new = Net::HTTP.method(:new)
    Net::HTTP.define_singleton_method(:new) { |_hostname, _port| fake_http.new(response) }

    begin
      error = assert_raises(RuntimeError) do
        Allmusic::HttpClient.get("https://www.allmusic.com/album/example")
      end

      assert_equal Allmusic::HttpClient::CLOUDFLARE_CHALLENGE_ERROR, error.message
    ensure
      Net::HTTP.define_singleton_method(:new) { |*args| original_new.call(*args) }
    end
  end
end
