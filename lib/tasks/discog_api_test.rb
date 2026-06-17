export DISCOGS_TOKEN="seu_token_aqui"

require "net/http"
require "json"
require "uri"

class DiscogsClient
  BASE_URL = "https://api.discogs.com"

  def initialize(token:)
    @token = token
  end

  def search_by_barcode(barcode)
    uri = URI("#{BASE_URL}/database/search")
    uri.query = URI.encode_www_form(
      barcode: barcode,
      type: "release"
    )

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Discogs token=#{@token}"
    request["User-Agent"] = "MinhaColecaoCD/1.0 +https://meusite.com"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "Erro Discogs: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def release(id)
    uri = URI("#{BASE_URL}/releases/#{id}")

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Discogs token=#{@token}"
    request["User-Agent"] = "MinhaColecaoCD/1.0 +https://meusite.com"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "Erro Discogs: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end

token = ENV.fetch("DISCOGS_TOKEN")
barcode = "724352198120"

discogs = DiscogsClient.new(token: token)

result = discogs.search_by_barcode(barcode)

if result["results"].empty?
  puts "Nenhum CD encontrado"
else
  item = result["results"].first

  puts "Encontrado:"
  puts "Título: #{item["title"]}"
  puts "Ano: #{item["year"]}"
  puts "País: #{item["country"]}"
  puts "Thumb: #{item["thumb"]}"
  puts "Discogs ID: #{item["id"]}"

  detalhes = discogs.release(item["id"])

  puts "\nFaixas:"
  detalhes["tracklist"]&.each do |track|
    puts "#{track["position"]} - #{track["title"]} #{track["duration"]}"
  end
end