require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should display total artists count" do
    get root_url
    assert_response :success
    assert_select ".stat-label", text: "Artists"
    assert_select ".stat-value", text: "1"
  end

  test "should display latest artists section" do
    get root_url
    assert_response :success
    assert_select "h3 span", text: "Latest Artists"
    assert_select ".dashboard-item-title", text: "Miles Davis"
  end
end
