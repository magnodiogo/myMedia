require "test_helper"

class UserMediaTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test_collector@example.com", password: "password", subscription_tier: "free")
    @media_type = MediaType.create!(name: "Vinyl LP")
    @artist = Artist.create!(name: "Pink Floyd")
    
    @medias = 4.times.map do |i|
      Media.create!(
        title: "Album #{i}",
        artist: @artist,
        media_type: @media_type
      )
    end
  end

  test "respects media limit for free users" do
    SystemSetting.set_free_user_media_limit(2)
    
    um1 = UserMedia.new(user: @user, media: @medias[0])
    assert um1.save
    
    um2 = UserMedia.new(user: @user, media: @medias[1])
    assert um2.save
    
    um3 = UserMedia.new(user: @user, media: @medias[2])
    assert_not um3.save
    assert_includes um3.errors[:base].first, "You have reached the limit"
  end

  test "does not limit media for paid users" do
    SystemSetting.set_free_user_media_limit(2)
    @user.update!(subscription_tier: "paid_monthly")
    
    assert UserMedia.create(user: @user, media: @medias[0])
    assert UserMedia.create(user: @user, media: @medias[1])
    um3 = UserMedia.new(user: @user, media: @medias[2])
    assert um3.save
  end
end
