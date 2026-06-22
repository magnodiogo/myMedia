require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @notification = notifications(:unread_notification)
  end

  test "should be valid with valid attributes" do
    assert @notification.valid?
  end

  test "should require title" do
    @notification.title = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:title], "can't be blank"
  end

  test "should require content" do
    @notification.content = nil
    assert_not @notification.valid?
    assert_includes @notification.errors[:content], "can't be blank"
  end

  test "should require user" do
    @notification.user = nil
    assert_not @notification.valid?
  end

  test "unread scope should return unread notifications only" do
    unread_notifications = Notification.unread
    assert_includes unread_notifications, notifications(:unread_notification)
    assert_not_includes unread_notifications, notifications(:read_notification)
  end
end
