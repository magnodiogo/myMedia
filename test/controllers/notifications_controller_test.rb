require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @admin = users(:two)
    @notification = notifications(:unread_notification)
  end

  test "should redirect to sign in if not logged in" do
    get notifications_url
    assert_redirected_to new_user_session_url
  end

  test "should get index when logged in" do
    sign_in @user
    get notifications_url
    assert_response :success
    assert_select "h1", text: "Notifications"
    # Verify user's notification title is visible
    assert_match @notification.title, response.body
  end

  test "should show notification and mark it as read" do
    sign_in @user
    assert_not @notification.read?
    
    get notification_url(@notification)
    assert_response :success
    assert_select "h2", text: @notification.title
    
    @notification.reload
    assert @notification.read?
  end

  test "should not show notification of another user" do
    sign_in @admin # Admin is user 'two', notification is for user 'one'
    
    get notification_url(@notification)
    assert_response :not_found
  end

  test "should mark all notifications as read" do
    sign_in @user
    assert_difference -> { @user.notifications.unread.count }, -1 do
      post read_all_notifications_url
    end
    assert_redirected_to notifications_url
    assert_equal "All notifications marked as read.", flash[:notice]
  end

  test "should destroy notification" do
    sign_in @user
    assert_difference("Notification.count", -1) do
      delete notification_url(@notification)
    end
    assert_redirected_to notifications_url
    assert_equal "Notification was successfully deleted.", flash[:notice]
  end

  test "should not destroy notification of another user" do
    sign_in @admin
    assert_no_difference("Notification.count") do
      delete notification_url(@notification)
      assert_response :not_found
    end
  end
end
