class PlansController < ApplicationController
  def index
    @free_limit = SystemSetting.free_user_media_limit
    @monthly_price = SystemSetting.monthly_subscription_price
    @yearly_price = SystemSetting.yearly_subscription_price
  end

  def upgrade
    tier = params[:tier] == "paid_yearly" ? "paid_yearly" : "paid_monthly"
    if current_user.update(subscription_tier: tier)
      redirect_to plans_path, notice: "Congratulations! Your Premium subscription has been successfully activated. You now have unlimited access!"
    else
      redirect_to plans_path, alert: "An error occurred while activating your subscription."
    end
  end

  def downgrade
    if current_user.update(subscription_tier: "free")
      redirect_to plans_path, notice: "Your Premium subscription has been cancelled. Your account is now free."
    else
      redirect_to plans_path, alert: "An error occurred while cancelling your subscription."
    end
  end
end
