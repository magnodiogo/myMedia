class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.free_user_media_limit
    setting = find_by(key: "free_user_media_limit")
    setting ? setting.value.to_i : 10
  end

  def self.set_free_user_media_limit(limit)
    setting = find_or_initialize_by(key: "free_user_media_limit")
    setting.value = limit.to_s
    setting.save
  end

  def self.monthly_subscription_price
    setting = find_by(key: "monthly_subscription_price")
    setting ? setting.value.to_f : 9.90
  end

  def self.set_monthly_subscription_price(price)
    setting = find_or_initialize_by(key: "monthly_subscription_price")
    setting.value = price.to_s
    setting.save
  end

  def self.yearly_subscription_price
    setting = find_by(key: "yearly_subscription_price")
    setting ? setting.value.to_f : 99.00
  end

  def self.set_yearly_subscription_price(price)
    setting = find_or_initialize_by(key: "yearly_subscription_price")
    setting.value = price.to_s
    setting.save
  end
end
