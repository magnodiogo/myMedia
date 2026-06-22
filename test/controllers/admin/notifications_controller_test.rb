require "test_helper"

class Admin::NotificationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @admin = users(:two)
    @notification = notifications(:unread_notification)
  end

  test "should redirect standard user to root with alert" do
    sign_in @user
    get admin_notifications_url
    assert_redirected_to root_url
    assert_equal "Only administrator users can perform this action.", flash[:alert]
  end

  test "should get index for admin" do
    sign_in @admin
    get admin_notifications_url
    assert_response :success
    assert_select "h1", text: "Manage Notifications"
  end

  test "should get new for admin" do
    sign_in @admin
    get new_admin_notification_url
    assert_response :success
    assert_select "h1", text: "Compose Notification"
  end

  test "should create targeted notification" do
    sign_in @admin
    assert_difference("Notification.count", 1) do
      post admin_notifications_url, params: {
        notification: { title: "Targeted Title", content: "Some content" },
        target_user_id: @user.id
      }
    end
    assert_redirected_to admin_notifications_url
    assert_equal "Notification successfully sent.", flash[:notice]

    new_notification = Notification.last
    assert_equal "Targeted Title", new_notification.title
    assert_equal "Some content", new_notification.content
    assert_equal @user, new_notification.user
  end

  test "should create broadcast notification for all common users" do
    sign_in @admin
    
    # We have users(:one) which is a CommonUser.
    # Let's count how many CommonUsers we have.
    common_users_count = User.where(type: "CommonUser").count
    assert common_users_count > 0

    assert_difference("Notification.count", common_users_count) do
      post admin_notifications_url, params: {
        notification: { title: "Broadcast Title", content: "Broadcast content" },
        target_user_id: "all"
      }
    end
    assert_redirected_to admin_notifications_url
    assert_equal "Notification successfully sent.", flash[:notice]
  end

  test "should fail to create notification if parameters are invalid" do
    sign_in @admin
    assert_no_difference("Notification.count") do
      post admin_notifications_url, params: {
        notification: { title: "", content: "" },
        target_user_id: ""
      }
    end
    assert_response :unprocessable_entity
    assert_match "Please fill in all fields.", response.body
  end

  test "should destroy notification for admin" do
    sign_in @admin
    assert_difference("Notification.count", -1) do
      delete admin_notification_url(@notification)
    end
    assert_redirected_to admin_notifications_url
    assert_equal "Notification successfully deleted.", flash[:notice]
  end
end
