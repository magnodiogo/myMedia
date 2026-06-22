require "test_helper"

class JsonWebTokenTest < ActiveSupport::TestCase
  test "should encode payload into jwt token" do
    payload = { user_id: 123 }
    token = JsonWebToken.encode(payload)

    assert_kind_of String, token
    assert token.present?
  end

  test "should decode valid jwt token" do
    payload = { user_id: 123 }
    token = JsonWebToken.encode(payload)
    decoded = JsonWebToken.decode(token)

    assert_not_nil decoded
    assert_equal 123, decoded[:user_id]
  end

  test "should return nil for invalid jwt token" do
    decoded = JsonWebToken.decode("invalid.token.string")
    assert_nil decoded
  end

  test "should handle token expiration" do
    payload = { user_id: 123 }
    # Encode with negative expiration (already expired)
    token = JsonWebToken.encode(payload, 1.second.ago)
    decoded = JsonWebToken.decode(token)

    assert_nil decoded
  end
end
