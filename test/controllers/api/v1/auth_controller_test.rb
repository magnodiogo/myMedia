require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "API Test User",
      email: "api_test@example.com",
      password: "correctpassword",
      password_confirmation: "correctpassword",
      subscription_tier: "free"
    )
  end

  test "should login successfully with correct credentials" do
    post api_v1_auth_login_url, params: {
      email: @user.email,
      password: "correctpassword"
    }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_not_nil json["token"]
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.name, json["user"]["name"]
    assert_equal @user.email, json["user"]["email"]
  end

  test "should fail login with incorrect credentials" do
    post api_v1_auth_login_url, params: {
      email: @user.email,
      password: "wrongpassword"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid email or password", json["error"]
  end

  test "should fail login with non-existent email" do
    post api_v1_auth_login_url, params: {
      email: "nonexistent@example.com",
      password: "correctpassword"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid email or password", json["error"]
  end

  test "should fail login for admin users" do
    admin_user = AdminUser.create!(
      name: "API Admin User",
      email: "api_admin@example.com",
      password: "correctpassword",
      password_confirmation: "correctpassword",
      subscription_tier: "free"
    )

    post api_v1_auth_login_url, params: {
      email: admin_user.email,
      password: "correctpassword"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid email or password", json["error"]
  end

  test "should get profile with valid token" do
    token = JsonWebToken.encode(user_id: @user.id)

    get api_v1_auth_me_url, headers: {
      "Authorization" => "Bearer #{token}"
    }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.name, json["user"]["name"]
  end

  test "should fail to get profile without token" do
    get api_v1_auth_me_url

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end

  test "should fail to get profile with invalid token" do
    get api_v1_auth_me_url, headers: {
      "Authorization" => "Bearer invalid.token.string"
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end
end
