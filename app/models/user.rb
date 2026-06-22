class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :user_media, class_name: "UserMedia", dependent: :destroy
  has_many :media, through: :user_media
  has_many :notifications, dependent: :destroy

  validates :subscription_tier, inclusion: { in: %w[free paid_monthly paid_yearly] }

  def admin?
    is_a?(AdminUser)
  end

  def free_tier?
    subscription_tier == "free"
  end

  def paid_tier?
    subscription_tier == "paid_monthly" || subscription_tier == "paid_yearly"
  end
end
