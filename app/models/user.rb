class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :user_media, class_name: "UserMedia", dependent: :destroy
  has_many :media, through: :user_media

  def admin?
    is_a?(AdminUser)
  end
end
