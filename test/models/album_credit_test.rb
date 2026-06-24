require "test_helper"

class AlbumCreditTest < ActiveSupport::TestCase
  setup do
    @media = media(:two)
  end

  test "should be valid with required attributes" do
    credit = AlbumCredit.new(
      media: @media,
      person_name: "Eric Clapton",
      role: "Vocals",
      source: "allmusic",
      raw_data: { "line" => "Eric Clapton Vocals" }
    )

    assert credit.valid?
  end

  test "should require person name, role, and source" do
    credit = AlbumCredit.new(media: @media)

    assert_not credit.valid?
    assert_includes credit.errors[:person_name], "can't be blank"
    assert_includes credit.errors[:role], "can't be blank"
    assert_includes credit.errors[:source], "can't be blank"
  end

  test "should classify credit category from role" do
    assert_equal "composer", AlbumCredit.category_for_role("Composer")
    assert_equal "musician", AlbumCredit.category_for_role("Bass (Electric)")
    assert_equal "technical", AlbumCredit.category_for_role("Producer")
  end
end
