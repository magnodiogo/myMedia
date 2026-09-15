# Seed Users
puts "Seeding Users..."
CommonUser.find_or_create_by!(email: "john@example.com") do |u|
  u.name = "John"
  u.password = "password123"
  u.password_confirmation = "password123"
end

AdminUser.find_or_create_by!(email: "admin@example.com") do |u|
  u.name = "Admin User"
  u.password = "password123"
  u.password_confirmation = "password123"
end

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

pink_floyd = Artist.find_by(name: "Pink Floyd")
if pink_floyd
  puts "Seeding Pink Floyd eras..."

  [
    ["Syd Barrett Era", Date.new(1965, 1, 1), Date.new(1968, 12, 31), 1],
    ["Transition Era", Date.new(1969, 1, 1), Date.new(1972, 12, 31), 2],
    ["Classic Era", Date.new(1973, 1, 1), Date.new(1979, 12, 31), 3],
    ["Post-Waters Era", Date.new(1987, 1, 1), Date.new(2014, 12, 31), 4]
  ].each do |name, starts_on, ends_on, position|
    pink_floyd.artist_eras.find_or_create_by!(name: name) do |era|
      era.starts_on = starts_on
      era.ends_on = ends_on
      era.position = position
    end
  end

  essential_pink_floyd = CollectionList.find_or_create_by!(slug: "essential-pink-floyd") do |list|
    list.name = "Essential Pink Floyd"
    list.list_type = "essential_albums"
  end

  ["The Dark Side of the Moon"].each_with_index do |title, index|
    medium = pink_floyd.media.find_by(title: title)
    next unless medium

    essential_pink_floyd.collection_list_items.find_or_create_by!(media: medium) do |item|
      item.position = index + 1
    end
  end

  piper = pink_floyd.albums.find_by(title: "The Piper at the Gates of Dawn")
  if piper
    puts "Seeding The Piper at the Gates of Dawn releases..."

    [
      ["The Piper at the Gates of Dawn", 1967, "Digital", "Columbia / Legacy", "G010003452566I", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0006576183"],
      ["The Piper at the Gates of Dawn", 1967, "Digital", "Pink Floyd", "G010003446085K", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0006575905"],
      ["The Piper at the Gates of Dawn", 1987, "Digital", "Capitol / EMI Records", "0077774638456", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0000715141"],
      ["The Piper at the Gates of Dawn", 1987, "CD", "Capitol", "C2-46384", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0001564371"],
      ["The Piper at the Gates of Dawn", 1994, "Cassette", "Capitol", "463844", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0000491178"],
      ["The Piper at the Gates of Dawn", 1994, "CD", "Capitol", "1073", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0001321008"],
      ["The Piper at the Gates of Dawn", 2001, "CD", "Phantom Import Distribution", "TOCP65731", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0000945238"],
      ["The Piper at the Gates of Dawn", 2001, "CD", "Toshiba EMI", "65731", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0001581094"],
      ["The Piper at the Gates of Dawn", 2004, "CD", "EMI Music Distribution", "CDEMDX1110", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0000468885"],
      ["The Piper at the Gates of Dawn", 2005, "LP", "Phantom Import Distribution", "CX6157", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0000706996"],
      ["The Piper at the Gates of Dawn", 2006, "LP", "EMD Int'l", "220183", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0001562635"],
      ["The Piper at the Gates of Dawn [Rock Milestones DVD]", 2006, "DVD", "Classic Rock Legends", "2071", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-rock-milestones-dvd--mr0001578404"],
      ["The Piper at the Gates of Dawn", 2007, "CD", "Toshiba EMI", "70300", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0001314743"],
      ["The Piper at the Gates of Dawn [3-CD Deluxe Edition]", 2007, "CD", "Capitol / EMI Records", "5039192", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-3-cd-deluxe-edition--mr0001314898"],
      ["The Piper at the Gates of Dawn [40th Anniversary 2-CD Edition]", 2007, "CD", "Capitol / EMI Records", "5039232", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-40th-anniversary-2-cd-edition--mr0000715350"],
      ["The Piper at the Gates of Dawn [40th Anniversary Complete Edition]", 2007, "Digital", "Parlophone", nil, "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-40th-anniversary-complete-edition--mr0001562633"],
      ["The Piper at the Gates of Dawn", 2011, "Digital", "Parlophone / Pink Floyd", nil, "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0004089923"],
      ["The Piper at the Gates of Dawn", 2011, "CD", "Parlophone / Warner Bros.", "CD 791504", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0004028431"],
      ["The Piper at the Gates of Dawn", 2011, "CD", "Capitol", "028935", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0003410051"],
      ["The Piper at the Gates of Dawn", 2011, "CD", "EMI", "0688731", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0003503662"],
      ["The Piper at the Gates of Dawn", 2012, "CD", "EMI Music Distribution", "TOCP54521", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0003668476"],
      ["The Piper at the Gates of Dawn", 2014, "CD", nil, "1092056", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0004075957"],
      ["The Piper at the Gates of Dawn", 2016, "CD", "Columbia", "88875170842", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0004511234"],
      ["The Piper at the Gates of Dawn", 2016, "LP", "Rhino", "2564649319", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0004564079"],
      ["The Piper at the Gates of Dawn [LP]", 2016, "LP", "Sony Music / Sony Music Entertainment", "88875184181", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-lp--mr0004563777"],
      ["The Piper at the Gates of Dawn", 2017, "CD", nil, "6631270", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0004797695"],
      ["The Piper at the Gates of Dawn", 2022, "LP", "Parlophone / Rhino / Warner Bros.", "9029502440", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0005596623"],
      ["The Piper at the Gates of Dawn", 2022, "Digital", "Columbia / Legacy", "G010004610407L", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mr0006575696"],
      ["The Piper at the Gates of Dawn [Mono Version]", 2022, "12 inch Vinyl Single", "Columbia / Legacy / Sony Music", "985961", "https://www.allmusic.com/album/release/the-piper-at-the-gates-of-dawn-mono-version--mr0005575803"]
    ].each_with_index do |(title, release_year, format, label, catalog_number, allmusic_url), index|
      release = piper.album_releases.find_or_initialize_by(allmusic_url: allmusic_url)
      release.assign_attributes(
        title: title,
        release_year: release_year,
        format: format,
        label: label,
        catalog_number: catalog_number,
        position: index + 1
      )
      release.save!
    end
  end
end

puts "Seeding completed successfully!"
