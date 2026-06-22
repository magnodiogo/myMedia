require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @admin = users(:two)
    sign_in @user
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should display total artists count" do
    get root_url
    assert_response :success
    assert_select ".stat-label", text: "Artists"
  end

  test "should display latest artists section" do
    get root_url
    assert_response :success
    assert_select "h3 span", text: "Latest Artists"
  end

  test "should display subscription and revenue overview for admin" do
    sign_out @user
    sign_in @admin

    get root_url
    assert_response :success
    assert_select "h3", text: "💎 Subscription & Revenue Overview"
    assert_select ".stat-label", text: "Premium Subscribers"
    assert_select ".stat-label", text: "Free Users"
    assert_select ".stat-label", text: "Est. Monthly Revenue"
    assert_select ".stat-label", text: "Est. Annual Revenue"
  end
end
