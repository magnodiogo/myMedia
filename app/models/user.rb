class User < ApplicationRecord
  has_many :user_media, class_name: "UserMedia", dependent: :destroy
  has_many :media, through: :user_media
end
