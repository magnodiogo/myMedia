require "test_helper"

class MediaTypeTest < ActiveSupport::TestCase
  test "should be valid with a name" do
    media_type = MediaType.new(name: "CD RedBook", description: "Audio CD format")
    assert media_type.valid?
  end

  test "should be invalid without a name" do
    media_type = MediaType.new(name: nil)
    assert_not media_type.valid?
    assert_includes media_type.errors[:name], "can't be blank"
  end

  test "should enforce uniqueness of name case insensitively" do
    MediaType.create!(name: "CD RedBook")
    duplicate = MediaType.new(name: "cd redbook")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end
end
