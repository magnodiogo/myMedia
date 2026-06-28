require "test_helper"

class CollectionListItemTest < ActiveSupport::TestCase
  setup do
    @collection_list = CollectionList.create!(
      name: "Essential Albums",
      slug: "essential-albums",
      list_type: "essential_albums"
    )
    @medium = media(:one)
  end

  test "should be valid with collection list and media" do
    item = CollectionListItem.new(collection_list: @collection_list, media: @medium)

    assert item.valid?
  end

  test "should require collection list" do
    item = CollectionListItem.new(media: @medium)

    assert_not item.valid?
    assert_includes item.errors[:collection_list], "must exist"
  end

  test "should require media" do
    item = CollectionListItem.new(collection_list: @collection_list)

    assert_not item.valid?
    assert_includes item.errors[:media], "must exist"
  end

  test "should require unique media per collection list" do
    CollectionListItem.create!(collection_list: @collection_list, media: @medium)
    duplicate = CollectionListItem.new(collection_list: @collection_list, media: @medium)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:media_id], "has already been taken"
  end
end
