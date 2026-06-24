require "test_helper"
require "minitest/mock"
require "open-uri"

class CreditPersonTest < ActiveSupport::TestCase
  test "should update bio from wikipedia" do
    person = CreditPerson.create!(name: "Leroy Carr")

    person.define_singleton_method(:fetch_wikipedia_summary) do |_title, _language|
      { "extract" => "Leroy Carr was an American blues singer.", "fullurl" => "https://en.wikipedia.org/wiki/Leroy_Carr" }
    end

    assert person.update_bio_from_wikipedia
    assert_equal "Leroy Carr was an American blues singer.", person.reload.bio
    assert_equal "https://en.wikipedia.org/wiki/Leroy_Carr", person.wikipedia_url
  end

  test "should update photo from wikipedia" do
    person = CreditPerson.create!(name: "Leroy Carr")

    person.define_singleton_method(:fetch_wikipedia_image_url) { |_title, _language| "https://example.com/leroy-carr.jpg" }
    person.define_singleton_method(:download_photo_from_url) { true }

    assert person.update_photo_from_wikipedia
    assert_equal "https://example.com/leroy-carr.jpg", person.photo_url
  end

  test "should download photo from url" do
    person = CreditPerson.new(name: "Photo Person")

    URI.stub :open, ->(*_args) { File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")) } do
      person.photo_url = "https://example.com/photo.jpg"
      assert person.save
      assert person.photo.attached?
    end
  end
end
