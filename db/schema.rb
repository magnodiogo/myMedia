# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_06_29_110500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "album_credits", force: :cascade do |t|
    t.bigint "media_id"
    t.string "person_name", null: false
    t.string "role", null: false
    t.string "source", null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "credit_person_id"
    t.string "credit_category", default: "technical", null: false
    t.bigint "album_id"
    t.index ["album_id", "credit_person_id", "role", "source"], name: "index_album_credits_on_album_person_role_source_id"
    t.index ["album_id", "person_name", "role", "source"], name: "index_album_credits_on_album_person_role_source"
    t.index ["album_id", "source"], name: "index_album_credits_on_album_id_and_source"
    t.index ["album_id"], name: "index_album_credits_on_album_id"
    t.index ["credit_person_id", "credit_category"], name: "index_album_credits_on_credit_person_id_and_credit_category"
    t.index ["credit_person_id"], name: "index_album_credits_on_credit_person_id"
    t.index ["media_id", "credit_person_id", "role", "source"], name: "index_album_credits_on_media_person_role_source_id"
    t.index ["media_id", "person_name", "role", "source"], name: "index_album_credits_on_media_person_role_source"
    t.index ["media_id", "source"], name: "index_album_credits_on_media_id_and_source"
    t.index ["media_id"], name: "index_album_credits_on_media_id"
  end

  create_table "album_genre_links", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "media_genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "media_genre_id"], name: "index_album_genre_links_on_album_id_and_media_genre_id", unique: true
    t.index ["album_id"], name: "index_album_genre_links_on_album_id"
    t.index ["media_genre_id"], name: "index_album_genre_links_on_media_genre_id"
  end

  create_table "album_recording_location_links", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "recording_location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "recording_location_id"], name: "index_album_recording_locations_unique", unique: true
    t.index ["album_id"], name: "index_album_recording_location_links_on_album_id"
    t.index ["recording_location_id"], name: "index_album_recording_location_links_on_recording_location_id"
  end

  create_table "album_releases", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.string "title", null: false
    t.integer "release_year"
    t.string "label"
    t.string "catalog_number"
    t.string "allmusic_url"
    t.text "info"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "media_type_id", null: false
    t.index ["album_id", "release_year", "position"], name: "index_album_releases_on_album_id_and_release_year_and_position"
    t.index ["album_id"], name: "index_album_releases_on_album_id"
    t.index ["allmusic_url"], name: "index_album_releases_on_allmusic_url", unique: true, where: "((allmusic_url IS NOT NULL) AND ((allmusic_url)::text <> ''::text))"
    t.index ["media_type_id"], name: "index_album_releases_on_media_type_id"
  end

  create_table "album_style_links", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "media_style_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "media_style_id"], name: "index_album_style_links_on_album_id_and_media_style_id", unique: true
    t.index ["album_id"], name: "index_album_style_links_on_album_id"
    t.index ["media_style_id"], name: "index_album_style_links_on_media_style_id"
  end

  create_table "albums", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "title", null: false
    t.integer "album_type", default: 0, null: false
    t.integer "metadata_status", default: 0, null: false
    t.integer "release_year"
    t.date "original_release_date"
    t.text "summary"
    t.string "slug"
    t.string "musicbrainz_release_group_id"
    t.string "wikidata_id"
    t.string "wikipedia_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "allmusic_url"
    t.datetime "allmusic_imported_at"
    t.text "allmusic_import_error"
    t.integer "duration_seconds"
    t.text "fun_facts"
    t.index ["allmusic_url"], name: "index_albums_on_allmusic_url"
    t.index ["artist_id", "title", "release_year"], name: "index_albums_on_artist_id_and_title_and_release_year"
    t.index ["artist_id"], name: "index_albums_on_artist_id"
    t.index ["duration_seconds"], name: "index_albums_on_duration_seconds"
    t.index ["musicbrainz_release_group_id"], name: "index_albums_on_musicbrainz_release_group_id", unique: true
    t.index ["slug"], name: "index_albums_on_slug", unique: true
    t.index ["wikidata_id"], name: "index_albums_on_wikidata_id"
  end

  create_table "artist_eras", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "name", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id", "position"], name: "index_artist_eras_on_artist_id_and_position"
    t.index ["artist_id"], name: "index_artist_eras_on_artist_id"
  end

  create_table "artists", force: :cascade do |t|
    t.string "name", null: false
    t.text "bio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.text "fun_facts"
    t.index ["name"], name: "index_artists_on_name", unique: true
    t.index ["slug"], name: "index_artists_on_slug", unique: true
  end

  create_table "collection_list_items", force: :cascade do |t|
    t.bigint "collection_list_id", null: false
    t.bigint "media_id", null: false
    t.integer "position", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["collection_list_id", "media_id"], name: "index_collection_list_items_on_collection_list_id_and_media_id", unique: true
    t.index ["collection_list_id", "position"], name: "index_collection_list_items_on_collection_list_id_and_position"
    t.index ["collection_list_id"], name: "index_collection_list_items_on_collection_list_id"
    t.index ["media_id"], name: "index_collection_list_items_on_media_id"
  end

  create_table "collection_lists", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "list_type", null: false
    t.boolean "public", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["list_type", "position"], name: "index_collection_lists_on_list_type_and_position"
    t.index ["slug"], name: "index_collection_lists_on_slug", unique: true
  end

  create_table "credit_people", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "bio"
    t.string "slug"
    t.string "wikipedia_url"
    t.string "allmusic_url"
    t.date "birth_date"
    t.string "birth_place"
    t.date "death_date"
    t.string "death_place"
    t.index ["allmusic_url"], name: "index_credit_people_on_allmusic_url"
    t.index ["name"], name: "index_credit_people_on_name", unique: true
    t.index ["slug"], name: "index_credit_people_on_slug", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "media", force: :cascade do |t|
    t.bigint "media_type_id", null: false
    t.string "title", null: false
    t.integer "release_year"
    t.string "catalog_number"
    t.string "barcode"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "artist_id", null: false
    t.text "info"
    t.string "slug"
    t.bigint "album_id", null: false
    t.string "allmusic_url"
    t.datetime "allmusic_imported_at"
    t.text "allmusic_import_error"
    t.integer "duration_seconds"
    t.bigint "album_release_id"
    t.index ["album_id"], name: "index_media_on_album_id"
    t.index ["album_release_id"], name: "index_media_on_album_release_id", unique: true
    t.index ["allmusic_url"], name: "index_media_on_allmusic_url"
    t.index ["artist_id"], name: "index_media_on_artist_id"
    t.index ["duration_seconds"], name: "index_media_on_duration_seconds"
    t.index ["media_type_id"], name: "index_media_on_media_type_id"
    t.index ["slug"], name: "index_media_on_slug", unique: true
  end

  create_table "media_genre_links", force: :cascade do |t|
    t.bigint "media_id", null: false
    t.bigint "media_genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["media_genre_id"], name: "index_media_genre_links_on_media_genre_id"
    t.index ["media_id", "media_genre_id"], name: "index_media_genre_links_on_media_id_and_media_genre_id", unique: true
    t.index ["media_id"], name: "index_media_genre_links_on_media_id"
  end

  create_table "media_genres", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_media_genres_on_name", unique: true
  end

  create_table "media_recording_location_links", force: :cascade do |t|
    t.bigint "media_id", null: false
    t.bigint "recording_location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["media_id", "recording_location_id"], name: "index_media_recording_locations_unique", unique: true
    t.index ["media_id"], name: "index_media_recording_location_links_on_media_id"
    t.index ["recording_location_id"], name: "index_media_recording_location_links_on_recording_location_id"
  end

  create_table "media_style_links", force: :cascade do |t|
    t.bigint "media_id", null: false
    t.bigint "media_style_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["media_id", "media_style_id"], name: "index_media_style_links_on_media_id_and_media_style_id", unique: true
    t.index ["media_id"], name: "index_media_style_links_on_media_id"
    t.index ["media_style_id"], name: "index_media_style_links_on_media_style_id"
  end

  create_table "media_styles", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_media_styles_on_name", unique: true
  end

  create_table "media_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_media_types_on_name", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.bigint "user_id", null: false
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "recording_locations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_recording_locations_on_name", unique: true
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "track_credits", force: :cascade do |t|
    t.bigint "track_id", null: false
    t.string "function"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["track_id"], name: "index_track_credits_on_track_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.bigint "media_id"
    t.string "title", null: false
    t.integer "track_number", null: false
    t.string "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "lyrics"
    t.string "position"
    t.bigint "album_id"
    t.integer "disc_number", default: 1, null: false
    t.string "musicbrainz_recording_id"
    t.index ["album_id", "disc_number", "track_number"], name: "index_tracks_on_album_id_and_disc_number_and_track_number"
    t.index ["album_id"], name: "index_tracks_on_album_id"
    t.index ["media_id"], name: "index_tracks_on_media_id"
    t.index ["musicbrainz_recording_id"], name: "index_tracks_on_musicbrainz_recording_id"
  end

  create_table "user_media", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "media_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "purchase_location"
    t.decimal "price_paid", precision: 8, scale: 2
    t.string "currency", default: "BRL"
    t.date "purchase_date"
    t.string "physical_location"
    t.string "condition"
    t.string "sleeve_condition"
    t.boolean "is_signed", default: false
    t.boolean "is_sealed", default: false
    t.string "edition_notes"
    t.index ["media_id"], name: "index_user_media_on_media_id"
    t.index ["user_id"], name: "index_user_media_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type", default: "CommonUser", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "theme"
    t.boolean "sidebar_collapsed"
    t.string "view_preference"
    t.integer "media_card_size"
    t.string "subscription_tier", default: "free", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "album_credits", "albums"
  add_foreign_key "album_credits", "credit_people"
  add_foreign_key "album_credits", "media"
  add_foreign_key "album_genre_links", "albums"
  add_foreign_key "album_genre_links", "media_genres"
  add_foreign_key "album_recording_location_links", "albums"
  add_foreign_key "album_recording_location_links", "recording_locations"
  add_foreign_key "album_releases", "albums"
  add_foreign_key "album_releases", "media_types"
  add_foreign_key "album_style_links", "albums"
  add_foreign_key "album_style_links", "media_styles"
  add_foreign_key "albums", "artists"
  add_foreign_key "artist_eras", "artists"
  add_foreign_key "collection_list_items", "collection_lists"
  add_foreign_key "collection_list_items", "media"
  add_foreign_key "media", "album_releases"
  add_foreign_key "media", "albums"
  add_foreign_key "media", "artists"
  add_foreign_key "media", "media_types"
  add_foreign_key "media_genre_links", "media"
  add_foreign_key "media_genre_links", "media_genres"
  add_foreign_key "media_recording_location_links", "media"
  add_foreign_key "media_recording_location_links", "recording_locations"
  add_foreign_key "media_style_links", "media"
  add_foreign_key "media_style_links", "media_styles"
  add_foreign_key "notifications", "users"
  add_foreign_key "track_credits", "tracks"
  add_foreign_key "tracks", "albums"
  add_foreign_key "tracks", "media"
  add_foreign_key "user_media", "media"
  add_foreign_key "user_media", "users"
end
