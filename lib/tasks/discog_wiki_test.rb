require "net/http"
require "json"
require "uri"
require "openssl"

unless defined?(Rails)
  require_relative "../../config/environment"
end

class HttpClient
  def self.get_json(uri, headers = {})
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?

    request = Net::HTTP::Get.new(uri)
    headers.each { |k, v| request[k] = v }

    response = http.request(request)

    raise "Erro HTTP #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)

    JSON.parse(response.body)
  end
end

class DiscogsClient
  BASE_URL = "https://api.discogs.com"

  def initialize(token:)
    @token = token
  end

  def search_by_barcode(barcode)
    uri = URI("#{BASE_URL}/database/search")
    uri.query = URI.encode_www_form(barcode: barcode, type: "release")
    HttpClient.get_json(uri, headers)
  end

  def release(id)
    uri = URI("#{BASE_URL}/releases/#{id}")
    HttpClient.get_json(uri, headers)
  end

  def artist(id)
    uri = URI("#{BASE_URL}/artists/#{id}")
    HttpClient.get_json(uri, headers)
  rescue => e
    puts "Error fetching artist on Discogs: #{e.message}"
    nil
  end

  private

  def headers
    {
      "Authorization" => "Discogs Token #{@token}",
      "User-Agent" => "ColecaoCDs/1.0"
    }
  end
end

class MusicBrainzClient
  BASE_URL = "https://musicbrainz.org/ws/2"

  def search_by_barcode(barcode)
    uri = URI("#{BASE_URL}/release/")
    uri.query = URI.encode_www_form(query: "barcode:#{barcode}", fmt: "json")
    HttpClient.get_json(uri, headers)
  rescue => e
    puts "MusicBrainz Error: #{e.message}"
    nil
  end

  def release_group(id)
    uri = URI("#{BASE_URL}/release-group/#{id}")
    uri.query = URI.encode_www_form(inc: "url-rels artist-credits", fmt: "json")
    HttpClient.get_json(uri, headers)
  rescue => e
    puts "MusicBrainz Release Group Error: #{e.message}"
    nil
  end

  def artist(id)
    uri = URI("#{BASE_URL}/artist/#{id}")
    uri.query = URI.encode_www_form(inc: "url-rels", fmt: "json")
    HttpClient.get_json(uri, headers)
  rescue => e
    puts "MusicBrainz Artist Error: #{e.message}"
    nil
  end

  private

  def headers
    {
      "User-Agent" => "ColecaoCDs/1.0 (seu-email@exemplo.com)"
    }
  end
end

class WikidataClient
  def entity(qid)
    uri = URI("https://www.wikidata.org/wiki/Special:EntityData/#{qid}.json")
    HttpClient.get_json(uri, { "User-Agent" => "ColecaoCDs/1.0" })
  rescue => e
    puts "Wikidata Error: #{e.message}"
    nil
  end

  def wikipedia_title(qid, language:)
    data = entity(qid)
    entity = data&.dig("entities", qid)
    entity&.dig("sitelinks", "#{language}wiki", "title")
  end
end

class WikipediaClient
  def initialize(language:)
    @language = language
  end

  def summary(title)
    uri = URI("https://#{@language}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(
      action: "query",
      prop: "extracts|info",
      exintro: true,
      explaintext: true,
      inprop: "url",
      titles: title,
      redirects: 1,
      format: "json"
    )

    data = HttpClient.get_json(uri, headers)
    page = data.dig("query", "pages")&.values&.first
    return nil if page.nil? || page["missing"]

    {
      "title" => page["title"],
      "extract" => page["extract"],
      "url" => page["fullurl"]
    }
  rescue => e
    puts "Erro Wikipedia #{@language}: #{e.message}"
    nil
  end

  private

  def headers
    { "User-Agent" => "ColecaoCDs/1.0" }
  end
end

def clean_artist_name(name)
  name.to_s.gsub(/\s\(\d+\)$/, "").strip
end

def clean_album_title(title)
  title = title.to_s.strip
  title = title.split(" - ", 2).last if title.include?(" - ")
  title
end

def extract_wikidata_id(url)
  url.to_s.split("/").last
end

def get_wikipedia_from_wikidata(wikidata, wikipedia_pt, wikipedia_en, qid)
  title_pt = wikidata.wikipedia_title(qid, language: "pt")
  sleep 0.5
  title_en = wikidata.wikipedia_title(qid, language: "en")

  data = nil
  language = nil
  title_used = nil

  if title_pt
    data = wikipedia_pt.summary(title_pt)
    language = "pt" if data
    title_used = title_pt if data
  end

  sleep 0.5

  if data.nil? && title_en
    data = wikipedia_en.summary(title_en)
    language = "en" if data
    title_used = title_en if data
  end

  {
    title_pt: title_pt,
    title_en: title_en,
    title_used: title_used,
    language: language,
    data: data
  }
end

def http_get(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = "CDCollection/1.0"
  http.request(request)
end

def fetch_lyrics(artist, track, album = nil)
  begin
    # Tentativa 1: busca exata
    uri = URI("https://lrclib.net/api/get")
    params = {
      artist_name: artist,
      track_name: track
    }
    params[:album_name] = album if album && !album.strip.empty?
    uri.query = URI.encode_www_form(params)

    response = http_get(uri)
    if response.code == "200"
      data = JSON.parse(response.body)
      lyrics = data["plainLyrics"]
      if lyrics && !lyrics.strip.empty?
        return { found: true, lyrics: lyrics, source: "lrclib" }
      end
    end

    # Tentativa 2: search
    uri = URI("https://lrclib.net/api/search")
    uri.query = URI.encode_www_form(
      artist_name: artist,
      track_name: track
    )

    response = http_get(uri)
    if response.code == "200"
      results = JSON.parse(response.body)
      item = results.find { |r| r["plainLyrics"] && !r["plainLyrics"].to_s.strip.empty? }
      if item
        return { found: true, lyrics: item["plainLyrics"], source: "lrclib_search" }
      end
    end

    { found: false, lyrics: nil }
  rescue => e
    { found: false, error: e.message }
  end
end


# ===========================================
# TESTE
# ===========================================

token = "TPfEJXlWcimuwWmFvvENlMGtyHbvJtqhsSzbpjuX"
barcode = "011105123426"
#barcode = "602438472529"

discogs = DiscogsClient.new(token: token)
musicbrainz = MusicBrainzClient.new
wikidata = WikidataClient.new
wikipedia_pt = WikipediaClient.new(language: "pt")
wikipedia_en = WikipediaClient.new(language: "en")

puts "Buscando no Discogs pelo código de barras #{barcode}..."
puts

discogs_result = discogs.search_by_barcode(barcode)

if discogs_result["results"].nil? || discogs_result["results"].empty?
  puts "Nenhum CD encontrado no Discogs."
  exit
end

item = discogs_result["results"].first
detalhes = discogs.release(item["id"])

artist_name = clean_artist_name(detalhes["artists"]&.first&.dig("name"))
album_title = clean_album_title(detalhes["title"])

artist_id = detalhes["artists"]&.first&.dig("id")
artist_photo_url = nil
if artist_id
  artist_details = discogs.artist(artist_id)
  artist_photo_url = artist_details&.dig("images")&.first&.dig("uri") if artist_details
end

puts "=" * 80
puts "DISCOGS"
puts "=" * 80
puts "Título Discogs : #{detalhes["title"]}"
puts "Álbum limpo    : #{album_title}"
puts "Artista        : #{artist_name}"
puts "Ano            : #{detalhes["year"]}"
puts "País           : #{detalhes["country"]}"
puts "Discogs ID     : #{detalhes["id"]}"
puts "Capa           : #{detalhes["images"]&.first&.dig("uri")}"
puts

if detalhes["labels"]&.any?
  puts "Gravadoras:"
  detalhes["labels"].each { |label| puts " - #{label["name"]} #{label["catno"]}" }
  puts
end

puts "Gêneros: #{detalhes["genres"].join(", ")}" if detalhes["genres"]&.any?
puts "Estilos: #{detalhes["styles"].join(", ")}" if detalhes["styles"]&.any?

if detalhes["tracklist"]&.any?
  puts
  puts "Faixas:"
  detalhes["tracklist"].each do |track|
    duration = track["duration"].to_s.empty? ? "" : " (#{track["duration"]})"
    puts "#{track["position"]} - #{track["title"]}#{duration}"
  end
end

puts
puts "=" * 80
puts "MUSICBRAINZ"
puts "=" * 80

mb_result = musicbrainz.search_by_barcode(barcode)
mb_release = mb_result&.dig("releases", 0)

album_wikidata_qid = nil
artist_mb_id = nil

if mb_release
  puts "Título        : #{mb_release["title"]}"
  puts "MusicBrainz ID: #{mb_release["id"]}"
  puts "Data          : #{mb_release["date"]}"
  puts "País          : #{mb_release["country"]}"
  puts "Status        : #{mb_release["status"]}"
  puts "Barcode       : #{mb_release["barcode"]}"

  mb_artists = mb_release["artist-credit"]&.map { |a| a.dig("artist", "name") }&.compact
  puts "Artistas      : #{mb_artists.join(", ")}" if mb_artists&.any?

  artist_mb_id = mb_release.dig("artist-credit", 0, "artist", "id")
  puts "Artist MB ID  : #{artist_mb_id}" if artist_mb_id

  mb_labels = mb_release["label-info"]&.map { |l| l.dig("label", "name") }&.compact
  puts "Gravadoras    : #{mb_labels.join(", ")}" if mb_labels&.any?

  release_group_id = mb_release.dig("release-group", "id")
  puts "Release Group : #{release_group_id}" if release_group_id

  if release_group_id
    rg = musicbrainz.release_group(release_group_id)

    if rg
      puts "Tipo Álbum    : #{rg["primary-type"]}"
      puts "Primeiro ano  : #{rg["first-release-date"]}"

      wikidata_url = rg["relations"]
        &.find { |rel| rel["type"] == "wikidata" }
        &.dig("url", "resource")

      if wikidata_url
        album_wikidata_qid = extract_wikidata_id(wikidata_url)
        puts "Album Wikidata: #{album_wikidata_qid}"
      end
    end
  end
else
  puts "Nenhum release encontrado no MusicBrainz."
end

puts
puts "=" * 80
puts "WIKIPEDIA DO ÁLBUM"
puts "=" * 80

if album_wikidata_qid
  album_wiki = get_wikipedia_from_wikidata(
    wikidata,
    wikipedia_pt,
    wikipedia_en,
    album_wikidata_qid
  )

  puts "Wikidata ID  : #{album_wikidata_qid}"
  puts "Wikipedia PT : #{album_wiki[:title_pt]}"
  puts "Wikipedia EN : #{album_wiki[:title_en]}"
  puts

  if album_wiki[:data]
    puts "Idioma : #{album_wiki[:language]}"
    puts "Título : #{album_wiki[:data]["title"]}"
    puts "URL    : #{album_wiki[:data]["url"]}"
    puts
    puts "Resumo:"
    puts album_wiki[:data]["extract"]
  else
    puts "Nenhum resumo do álbum encontrado."
  end
else
  puts "Álbum sem Wikidata encontrado via MusicBrainz."
end

puts
puts "=" * 80
puts "WIKIPEDIA DO ARTISTA"
puts "=" * 80

if artist_mb_id
  mb_artist = musicbrainz.artist(artist_mb_id)

  artist_wikidata_url = mb_artist&.dig("relations")
    &.find { |rel| rel["type"] == "wikidata" }
    &.dig("url", "resource")

  if artist_wikidata_url
    artist_wikidata_qid = extract_wikidata_id(artist_wikidata_url)

    artist_wiki = get_wikipedia_from_wikidata(
      wikidata,
      wikipedia_pt,
      wikipedia_en,
      artist_wikidata_qid
    )

    puts "Artist MB ID : #{artist_mb_id}"
    puts "Wikidata ID  : #{artist_wikidata_qid}"
    puts "Wikipedia PT : #{artist_wiki[:title_pt]}"
    puts "Wikipedia EN : #{artist_wiki[:title_en]}"
    puts

    if artist_wiki[:data]
      puts "Idioma : #{artist_wiki[:language]}"
      puts "Título : #{artist_wiki[:data]["title"]}"
      puts "URL    : #{artist_wiki[:data]["url"]}"
      puts
      puts "Resumo:"
      puts artist_wiki[:data]["extract"]
    else
      puts "Nenhum resumo do artista encontrado."
    end
  else
    puts "Nenhum Wikidata encontrado para o artista no MusicBrainz."
  end
else
  puts "Nenhum artista MusicBrainz encontrado."
end

# ===========================================
# SAVING TO DATABASE
# ===========================================
puts
puts "=" * 80
puts "SAVING TO DATABASE"
puts "=" * 80

# 1. Encontrar ou inicializar a Mídia por código de barras
media = Media.find_or_initialize_by(barcode: barcode)

# 2. Definir / Atualizar atributos da Mídia
media.title = album_title
media.release_year = detalhes["year"]
media.catalog_number = detalhes["labels"]&.first&.dig("catno")
media.cover_url = detalhes["images"]&.first&.dig("uri") if detalhes["images"]&.any?

# Garantir que temos um tipo de mídia padrão (e.g. CD RedBook ou o primeiro disponível)
media.media_type ||= MediaType.find_by(name: "CD RedBook") || MediaType.first

# 3. Guardar resumo do álbum da Wikipedia
if defined?(album_wiki) && album_wiki && album_wiki[:data] && album_wiki[:data]["extract"]
  media.info = album_wiki[:data]["extract"]
end

# 4. Encontrar/Criar o Artista pelo nome e atualizar a sua bio e foto
artist = Artist.find_or_initialize_by(name: artist_name)
if defined?(artist_wiki) && artist_wiki && artist_wiki[:data] && artist_wiki[:data]["extract"]
  artist.bio = artist_wiki[:data]["extract"]
end
if defined?(artist_photo_url) && artist_photo_url.present? && !artist.photo.attached?
  artist.photo_url = artist_photo_url
end
artist.save!
media.artist = artist

# Salvar a mídia (isso também fará o download da capa se cover_url estiver presente)
Media.skip_callback(:commit, :after, :enrich_metadata)
if media.save
  puts "Media '#{media.title}' (ID: #{media.id}) successfully saved!"
else
  puts "Error saving media: #{media.errors.full_messages.join(', ')}"
  exit 1
end

# 5. Gravar automaticamente as faixas do disco
if detalhes["tracklist"]&.any?
  puts "Saving tracks for media..."
  media.tracks.destroy_all # Limpar faixas anteriores para recriar a lista limpa
  
  # Filtrar para ter apenas faixas válidas (ignorar cabeçalhos/headings da tracklist do Discogs se houver)
  tracks_to_save = detalhes["tracklist"].select { |t| t["type_"].nil? || t["type_"] == "track" || t["type_"].empty? }
  
  tracks_to_save.each_with_index do |track_data, index|
    track_number = index + 1
    
    # Validar e normalizar a duração. A validação exige formato MM:SS.
    duration = track_data["duration"].to_s.strip
    duration = nil unless duration =~ /\A\d+:\d{2}\z/
    
    # Buscar letra para esta faixa
    lyrics_res = fetch_lyrics(artist.name, track_data["title"], media.title)
    lyrics = lyrics_res[:lyrics]
    
    track = media.tracks.create!(
      title: track_data["title"],
      track_number: track_number,
      position: track_data["position"],
      duration: duration,
      lyrics: lyrics
    )
    
    if track_data["extraartists"]&.any?
      track_data["extraartists"].each do |extra_artist|
        role = extra_artist["role"].to_s.strip
        name = clean_artist_name(extra_artist["name"])
        next if role.blank? || name.blank?

        track.track_credits.create!(
          function: role,
          name: name
        )
      end
    end
    puts " - Track #{track.track_number} [#{track.position}]: #{track.title}#{duration ? " (#{duration})" : ""}#{lyrics ? ' (Lyrics saved)' : ' (No lyrics)'}"
    sleep 0.5 # be polite to API
  end
  puts "Total of #{media.tracks.count} tracks successfully saved!"
end