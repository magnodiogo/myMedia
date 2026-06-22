require "test_helper"

class MediaControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @media_type = MediaType.create!(name: "CD RedBook", description: "Audio CD")
    @admin = users(:two)
    sign_in @admin
    @media = Media.create!(
      media_type: @media_type,
      title: "The Dark Side of the Moon",
      artist: "Pink Floyd",
      release_year: 1973,
      catalog_number: "CDP 7 46001 2",
      barcode: "077774600121",
      notes: "First pressing"
    )
    UserMedia.create!(user: User.first, media: @media)
  end


  test "should get index" do
    get media_index_url
    assert_response :success
  end

  test "should get index with search matching title" do
    get media_index_url, params: { search: "Dark Side" }
    assert_response :success
    assert_select "h2.media-title", text: "The Dark Side of the Moon"
  end

  test "should get index with search matching artist" do
    get media_index_url, params: { search: "Pink Floyd" }
    assert_response :success
    assert_select "h2.media-title", text: "The Dark Side of the Moon"
  end

  test "should get index with search not matching" do
    get media_index_url, params: { search: "NonExistentAlbum" }
    assert_response :success
    assert_select "h2.media-title", count: 0
  end

  test "should get new" do
    get new_media_url
    assert_response :success
  end

  test "should create media" do
    assert_difference("Media.count") do
      post media_index_url, params: {
        media: {
          media_type_id: @media_type.id,
          title: "Thriller",
          artist: "Michael Jackson",
          release_year: 1982,
          catalog_number: "EK 38112",
          barcode: "07464381122",
          notes: "Sample notes"
        }
      }
    end

    assert_redirected_to media_index_url
  end

  test "should create media with a cover_image" do
    cover = fixture_file_upload(Rails.root.join("db/seeds/images/dark_side_cover.png"), "image/png")
    assert_difference("Media.count") do
      post media_index_url, params: {
        media: {
          media_type_id: @media_type.id,
          title: "Thriller with Cover",
          artist: "Michael Jackson",
          cover_image: cover
        }
      }
    end

    assert_redirected_to media_index_url
    new_media = Media.last
    assert new_media.cover_image.attached?
    
    path = ActiveStorage::Blob.service.path_for(new_media.cover_image.key)
    if system("which identify > /dev/null 2>&1")
      dimensions = `identify -format "%wx%h" #{path}`.split("x").map(&:to_i)
      assert_operator dimensions[0], :<=, 600
      assert_operator dimensions[1], :<=, 600
    else
      warn "Warning: ImageMagick 'identify' command not found, skipping image dimensions assertion."
    end
  end

  test "should show media" do
    get media_url(@media)
    assert_response :success
  end

  test "should get edit" do
    get edit_media_url(@media)
    assert_response :success
  end

  test "should update media" do
    patch media_url(@media), params: {
      media: {
        title: "The Dark Side of the Moon (Updated)",
        artist: "Pink Floyd (Updated)"
      }
    }
    assert_redirected_to media_url(@media)
    @media.reload
    assert_equal "The Dark Side of the Moon (Updated)", @media.title
    assert_equal "Pink Floyd (Updated)", @media.artist.name
  end

  test "should destroy media" do
    assert_difference("Media.count", -1) do
      delete media_url(@media)
    end

    assert_redirected_to media_index_url
  end

  test "common user should get new, create, and import_and_add media, but not edit, update, or destroy" do
    post switch_user_sessions_url, params: { user_id: users(:one).id }
    
    get new_media_url
    assert_response :success

    assert_difference("Media.count") do
      post media_index_url, params: {
        media: {
          media_type_id: @media_type.id,
          title: "New Album Common User",
          artist: "New Artist Common User"
        }
      }
    end
    assert_redirected_to media_index_url

    assert_difference("Media.count") do
      post import_and_add_media_url, params: {
        title: "Imported Album Common User",
        artist: "Imported Artist Common User",
        media_type_id: @media_type.id
      }
    end
    assert_response :success

    get edit_media_url(@media)
    assert_redirected_to root_url

    patch media_url(@media), params: { media: { title: "Dark Side Updated" } }
    assert_redirected_to root_url
    @media.reload
    assert_not_equal "Dark Side Updated", @media.title

    assert_no_difference("Media.count") do
      delete media_url(@media)
    end
    assert_redirected_to root_url
  end
end
