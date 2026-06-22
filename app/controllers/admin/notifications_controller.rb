module Admin
  class NotificationsController < ApplicationController
    before_action :require_admin!
    before_action :set_notification, only: [:destroy]

    def index
      @notifications = Notification.includes(:user).order(created_at: :desc)
    end

    def new
      @notification = Notification.new
      @users = User.where(type: "CommonUser").order(:name, :email)
    end

    def create
      title = params.dig(:notification, :title)
      content = params.dig(:notification, :content)
      target = params[:target_user_id]

      if title.blank? || content.blank? || target.blank?
        flash.now[:alert] = "Please fill in all fields."
        @notification = Notification.new(title: title, content: content)
        @users = User.where(type: "CommonUser").order(:name, :email)
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if target == "all"
          User.where(type: "CommonUser").each do |u|
            u.notifications.create!(title: title, content: content)
          end
        else
          user = User.find(target)
          user.notifications.create!(title: title, content: content)
        end
      end

      redirect_to admin_notifications_path, notice: "Notification successfully sent."
    rescue => e
      flash.now[:alert] = "Error sending notification: #{e.message}"
      @notification = Notification.new(title: title, content: content)
      @users = User.where(type: "CommonUser").order(:name, :email)
      render :new, status: :unprocessable_entity
    end

    def destroy
      @notification.destroy
      redirect_to admin_notifications_path, notice: "Notification successfully deleted."
    end

    private

    def set_notification
      @notification = Notification.find(params[:id])
    end
  end
end
