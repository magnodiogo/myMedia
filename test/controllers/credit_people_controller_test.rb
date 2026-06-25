require "test_helper"

class CreditPeopleControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
    @media = media(:two)
    @person = CreditPerson.create!(
      name: "Leroy Carr",
      bio: "Leroy Carr was an American blues singer.",
      wikipedia_url: "https://en.wikipedia.org/wiki/Leroy_Carr",
      allmusic_url: "https://www.allmusic.com/artist/leroy-carr-mn0000251494"
    )
    @media.album_credits.create!(
      credit_person: @person,
      person_name: @person.name,
      role: "Composer",
      source: "allmusic"
    )
  end

  test "should show credited media for person" do
    get credit_person_url(@person)

    assert_response :success
    assert_select "h1.page-title", text: "Leroy Carr"
    assert_select ".artist-biography", minimum: 1
    assert_select "a[href=?]", @person.wikipedia_url, text: "Wikipedia"
    assert_select "a[href=?]", @person.allmusic_url, text: "AllMusic"
    assert_select ".tab-link", text: "Other Media"
    assert_select ".tab-link", text: "Roles"
    assert_select "h2.media-title", text: @media.album.title
    assert_select ".media-card", minimum: 1
    assert_select ".media-card-cover-container", minimum: 1
  end

  test "admin should load person metadata" do
    sign_in users(:two)

    @person.define_singleton_method(:load_external_data) do
      { allmusic: true, wikipedia_bio: true, wikipedia_photo: false, bio: true, photo: false, errors: [] }
    end

    original_friendly = CreditPerson.method(:friendly)
    original_find = CreditPerson.method(:find)
    person = @person
    CreditPerson.define_singleton_method(:friendly) { CreditPerson }
    CreditPerson.define_singleton_method(:find) { |_id| person }

    begin
      post load_metadata_credit_person_url(@person)
    ensure
      CreditPerson.define_singleton_method(:friendly) { |*args| original_friendly.call(*args) }
      CreditPerson.define_singleton_method(:find) { |*args| original_find.call(*args) }
    end

    assert_redirected_to credit_person_url(@person)
    assert_equal "Person data loaded from AllMusic and Wikipedia biography.", flash[:notice]
  end

  test "common user should not load person metadata" do
    post load_metadata_credit_person_url(@person)

    assert_redirected_to root_path
  end

end
