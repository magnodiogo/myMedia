class NotificationsController < ApplicationController
  before_action :set_notification, only: [:show, :destroy]

  def index
    @notifications = current_user.notifications.order(created_at: :desc)
  end

  def show
    @notification.update(read: true) unless @notification.read?
  end

  def read_all
    current_user.notifications.unread.update_all(read: true)
    redirect_to notifications_path, notice: "All notifications marked as read."
  end

  def destroy
    @notification.destroy
    redirect_to notifications_path, notice: "Notification was successfully deleted."
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
