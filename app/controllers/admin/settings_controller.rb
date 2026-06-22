module Admin
  class SettingsController < ApplicationController
    before_action :require_admin!

    def show
      @free_limit = SystemSetting.free_user_media_limit
      @monthly_price = SystemSetting.monthly_subscription_price
      @yearly_price = SystemSetting.yearly_subscription_price
    end

    def update
      limit = params[:free_user_media_limit].to_i
      monthly_price = params[:monthly_subscription_price].to_f
      yearly_price = params[:yearly_subscription_price].to_f

      if limit <= 0
        redirect_to admin_settings_path, alert: "The limit must be an integer greater than zero."
        return
      end

      if monthly_price <= 0 || yearly_price <= 0
        redirect_to admin_settings_path, alert: "Prices must be positive numbers."
        return
      end

      SystemSetting.set_free_user_media_limit(limit)
      SystemSetting.set_monthly_subscription_price(monthly_price)
      SystemSetting.set_yearly_subscription_price(yearly_price)

      redirect_to admin_settings_path, notice: "System settings successfully updated."
    end
  end
end
