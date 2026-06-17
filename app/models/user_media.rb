class UserMedia < ApplicationRecord
  belongs_to :user
  belongs_to :media
end
