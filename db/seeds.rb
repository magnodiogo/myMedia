# Seed MediaTypes
puts "Seeding Media Types..."
cd_redbook = MediaType.find_or_create_by!(name: "CD RedBook") do |mt|
  mt.description = "Compact Disc Digital Audio (CD-DA), standard physical audio format containing PCM encoded digital audio."
end

vinyl_lp = MediaType.find_or_create_by!(name: "Vinyl LP") do |mt|
  mt.description = "Long Play 12-inch analog vinyl record, typically running at 33 1/3 rpm."
end

cassette = MediaType.find_or_create_by!(name: "Cassette Tape") do |mt|
  mt.description = "Compact Cassette magnetic tape analog audio format."
end

dvd_audio = MediaType.find_or_create_by!(name: "DVD Audio") do |mt|
  mt.description = "Digital Versatile Disc high-fidelity audio format."
end

puts "Seeding Media items..."

# Seed sample media under CD RedBook
m1 = Media.find_or_create_by!(title: "The Dark Side of the Moon", artist: "Pink Floyd") do |m|
  m.media_type = cd_redbook
  m.release_year = 1973
  m.catalog_number = "CDP 7 46001 2"
  m.barcode = "077774600121"
  m.notes = "Standard RedBook CD edition. Remastered by James Guthrie."
end
if !m1.cover_image.attached?
  m1.cover_image.attach(
    io: File.open(Rails.root.join("db/seeds/images/dark_side_cover.png")),
    filename: "dark_side_cover.png",
    content_type: "image/png"
  )
end

m2 = Media.find_or_create_by!(title: "Thriller", artist: "Michael Jackson") do |m|
  m.media_type = cd_redbook
  m.release_year = 1982
  m.catalog_number = "EK 38112"
  m.barcode = "07464381122"
  m.notes = "Early US CD pressing, manufactured by DADC."
end
if !m2.cover_image.attached?
  m2.cover_image.attach(
    io: File.open(Rails.root.join("db/seeds/images/thriller_cover.png")),
    filename: "thriller_cover.png",
    content_type: "image/png"
  )
end

m3 = Media.find_or_create_by!(title: "Kind of Blue", artist: "Miles Davis") do |m|
  m.media_type = cd_redbook
  m.release_year = 1959
  m.catalog_number = "CK 64935"
  m.barcode = "074646493520"
  m.notes = "Columbia Jazz Masterpieces series reissue."
end
if !m3.cover_image.attached?
  m3.cover_image.attach(
    io: File.open(Rails.root.join("db/seeds/images/kind_of_blue_cover.png")),
    filename: "kind_of_blue_cover.png",
    content_type: "image/png"
  )
end

# Seed sample media under Vinyl LP (without covers for now, demonstrating fallback)
Media.find_or_create_by!(title: "Abbey Road", artist: "The Beatles") do |m|
  m.media_type = vinyl_lp
  m.release_year = 1969
  m.catalog_number = "PCS 7088"
  m.barcode = "0094638246817"
  m.notes = "UK original stereo mix LP reprint."
end

Media.find_or_create_by!(title: "Rumours", artist: "Fleetwood Mac") do |m|
  m.media_type = vinyl_lp
  m.release_year = 1977
  m.catalog_number = "BSK 3010"
  m.barcode = "075992731313"
  m.notes = "Textured sleeve reissue."
end

puts "Seeding completed successfully!"
