class UserMedia < ApplicationRecord
  belongs_to :user
  belongs_to :media

  validate :check_media_limit_for_free_users, on: :create

  CONDITIONS = [
    ["Mint (M)", "M"],
    ["Near Mint (NM)", "NM"],
    ["Very Good Plus (VG+)", "VG+"],
    ["Very Good (VG)", "VG"],
    ["Good Plus (G+)", "G+"],
    ["Good (G)", "G"],
    ["Fair (F)", "F"],
    ["Poor (P)", "P"]
  ].freeze

  CURRENCIES = ["BRL", "USD", "EUR", "GBP"].freeze

  private

  def check_media_limit_for_free_users
    if user && user.free_tier?
      limit = SystemSetting.free_user_media_limit
      if user.user_media.count >= limit
        errors.add(:base, "You have reached the limit of #{limit} physical media items for free accounts. Please upgrade to the Premium plan to add more physical media.")
      end
    end
  end
end
