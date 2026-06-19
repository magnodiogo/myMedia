#!/usr/bin/env ruby

require "net/http"
require "json"
require "uri"
require "openssl"

album_artist = "Pink Floyd"
album_title  = "The Dark Side of the Moon"

tracks = [
  "Speak to Me",
  "Breathe",
  "Time",
  "Money"
]

def http_get(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")

  # SOMENTE PARA TESTE
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = "CDCollection/1.0"

  http.request(request)
end

def fetch_lyrics(artist, track, album = nil)
  begin
    #
    # Tentativa 1: busca exata
    #
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
        return {
          found: true,
          lyrics: lyrics,
          source: "lrclib"
        }
      end
    end

    #
    # Tentativa 2: search
    #
    uri = URI("https://lrclib.net/api/search")

    uri.query = URI.encode_www_form(
      artist_name: artist,
      track_name: track
    )

    response = http_get(uri)

    if response.code == "200"
      results = JSON.parse(response.body)

      item = results.find do |r|
        r["plainLyrics"] &&
          !r["plainLyrics"].to_s.strip.empty?
      end

      if item
        return {
          found: true,
          lyrics: item["plainLyrics"],
          source: "lrclib_search"
        }
      end
    end

    {
      found: false,
      lyrics: nil
    }

  rescue => e
    {
      found: false,
      error: e.message
    }
  end
end

puts
puts "=" * 80
puts "#{album_artist} - #{album_title}"
puts "=" * 80

tracks.each do |track|
  puts
  puts "-" * 80
  puts "Track: #{track}"

  result = fetch_lyrics(album_artist, track, album_title)

  if result[:found]
    lyrics = result[:lyrics].to_s

    puts "✓ LETRA ENCONTRADA"
    puts "Fonte: #{result[:source]}"
    puts "Tamanho: #{lyrics.length} caracteres"

    puts
   # puts lyrics[0..500]
     puts lyrics
    #puts "\n..."
  else
    puts "✗ Letra não encontrada"

    if result[:error]
      puts result[:error]
    end
  end

  sleep 1
end