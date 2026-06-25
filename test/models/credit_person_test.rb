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

  test "should load external data from allmusic and wikipedia" do
    person = CreditPerson.create!(name: "Chris Stainton", allmusic_url: "https://www.allmusic.com/artist/chris-stainton-mn0000108437")
    allmusic_result = {
      success: true,
      skipped: false,
      error: nil,
      parsed: {
        bio: "Chris Stainton is an English keyboardist.",
        image_url: nil
      }
    }

    original_call = Allmusic::ImportPersonService.method(:call)
    begin
      Allmusic::ImportPersonService.define_singleton_method(:call) { |_person| allmusic_result }
      person.define_singleton_method(:fetch_wikipedia_summary) do |_title, _language|
        { "extract" => "Wikipedia biography for Chris Stainton.", "fullurl" => "https://en.wikipedia.org/wiki/Chris_Stainton" }
      end
      person.define_singleton_method(:fetch_wikipedia_image_url) { |_title, _language| "https://example.com/chris-stainton.jpg" }
      person.define_singleton_method(:download_photo_from_url) { true }

      result = person.load_external_data
    ensure
      Allmusic::ImportPersonService.define_singleton_method(:call) { |*args| original_call.call(*args) }
    end

    assert result[:wikipedia_bio]
    assert result[:wikipedia_photo]
    assert result[:bio]
    assert result[:photo]
    assert_not result[:allmusic]
    assert_equal "Wikipedia biography for Chris Stainton.", person.reload.bio
    assert_equal "https://en.wikipedia.org/wiki/Chris_Stainton", person.wikipedia_url
  end

  test "should load wikipedia bio using existing wikipedia url title before name" do
    person = CreditPerson.create!(
      name: "Andy Fairweather Low",
      wikipedia_url: "https://en.wikipedia.org/wiki/Andy_Fairweather-Low"
    )
    allmusic_result = { success: false, skipped: true, error: "AllMusic URL is blank", parsed: {} }

    original_call = Allmusic::ImportPersonService.method(:call)
    begin
      Allmusic::ImportPersonService.define_singleton_method(:call) { |_person| allmusic_result }
      person.define_singleton_method(:fetch_wikipedia_summary) do |title, language|
        if title == "Andy Fairweather-Low" && language == "en"
          { "extract" => "Andy Fairweather Low is a Welsh guitarist.", "fullurl" => "https://en.wikipedia.org/wiki/Andy_Fairweather-Low" }
        end
      end
      person.define_singleton_method(:fetch_wikipedia_image_url) { |_title, _language| nil }

      result = person.load_external_data
    ensure
      Allmusic::ImportPersonService.define_singleton_method(:call) { |*args| original_call.call(*args) }
    end

    assert result[:wikipedia_bio]
    assert result[:bio]
    assert_equal "Andy Fairweather Low is a Welsh guitarist.", person.reload.bio
  end

  test "should replace existing biography with wikipedia biography when loading external data" do
    person = CreditPerson.create!(
      name: "Andy Fairweather Low",
      bio: "Older AllMusic biography.",
      wikipedia_url: "https://en.wikipedia.org/wiki/Andy_Fairweather_Low"
    )
    allmusic_result = { success: false, skipped: true, error: "AllMusic URL is blank", parsed: {} }

    original_call = Allmusic::ImportPersonService.method(:call)
    begin
      Allmusic::ImportPersonService.define_singleton_method(:call) { |_person| allmusic_result }
      person.define_singleton_method(:fetch_wikipedia_summary) do |title, language|
        if title == "Andy Fairweather Low" && language == "en"
          { "extract" => "Wikipedia biography for Andy.", "fullurl" => "https://en.wikipedia.org/wiki/Andy_Fairweather_Low" }
        end
      end
      person.define_singleton_method(:fetch_wikipedia_image_url) { |_title, _language| nil }

      result = person.load_external_data
    ensure
      Allmusic::ImportPersonService.define_singleton_method(:call) { |*args| original_call.call(*args) }
    end

    assert result[:wikipedia_bio]
    assert result[:bio]
    assert_equal "Wikipedia biography for Andy.", person.reload.bio
  end

  test "should parse allmusic person biography and image" do
    html = <<~HTML
      <html>
        <head><meta property="og:image" content="/images/chris.jpg"></head>
        <body>
          <h1>Chris Stainton</h1>
          <div class="artist-biography">English keyboardist and songwriter.</div>
        </body>
      </html>
    HTML

    parsed = Allmusic::PersonParser.call(html)

    assert_equal "Chris Stainton", parsed[:name]
    assert_equal "English keyboardist and songwriter.", parsed[:bio]
    assert_equal "https://www.allmusic.com/images/chris.jpg", parsed[:image_url]
  end
end
