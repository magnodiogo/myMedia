require "test_helper"

class CollectionListTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    collection_list = CollectionList.new(
      name: "Essential Albums",
      slug: "essential-albums",
      list_type: "essential_albums"
    )

    assert collection_list.valid?
  end

  test "should require name" do
    collection_list = CollectionList.new(slug: "essential-albums", list_type: "essential_albums")

    assert_not collection_list.valid?
    assert_includes collection_list.errors[:name], "can't be blank"
  end

  test "should require slug" do
    collection_list = CollectionList.new(name: "Essential Albums", list_type: "essential_albums")

    assert_not collection_list.valid?
    assert_includes collection_list.errors[:slug], "can't be blank"
  end

  test "should require unique slug" do
    CollectionList.create!(name: "Essential Albums", slug: "essential-albums", list_type: "essential_albums")
    duplicate = CollectionList.new(name: "Other Albums", slug: "essential-albums", list_type: "custom")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should require supported list type" do
    collection_list = CollectionList.new(name: "Essential Albums", slug: "essential-albums", list_type: "unknown")

    assert_not collection_list.valid?
    assert_includes collection_list.errors[:list_type], "is not included in the list"
  end
end
