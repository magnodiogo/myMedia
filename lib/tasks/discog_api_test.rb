require "net/http"
require "json"
require "uri"
require "openssl"

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
    request["Authorization"] = "Discogs Token=#{@token}"
    request["User-Agent"] = "ColecaoCDs/1.0"

    response = perform_request(uri, request)

    JSON.parse(response.body)
  end

  def release(id)
    uri = URI("#{BASE_URL}/releases/#{id}")

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Discogs token=#{@token}"
    request["User-Agent"] = "ColecaoCDs/1.0"

    response = perform_request(uri, request)

    JSON.parse(response.body)
  end

  private

  def perform_request(uri, request)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true

    # SOMENTE PARA TESTE
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    response = http.request(request)

    case response.code.to_i
    when 200
      response
    when 401
      raise "Token inválido"
    when 404
      raise "Registro não encontrado"
    when 429
      raise "Limite de requisições excedido"
    else
      raise "Erro Discogs #{response.code}: #{response.body}"
    end
  end
end

# ===========================================
# TESTE
# ===========================================

token = "TPfEJXlWcimuwWmFvvENlMGtyHbvJtqhsSzbpjuX"

barcode = "886976670320"

discogs = DiscogsClient.new(token: token)

puts "Buscando código de barras #{barcode}..."
puts

result = discogs.search_by_barcode(barcode)

if result["results"].nil? || result["results"].empty?
  puts "Nenhum CD encontrado."
  exit
end

item = result["results"].first

puts "=" * 80
puts "RESULTADO"
puts "=" * 80
puts "Título    : #{item["title"]}"
puts "Ano       : #{item["year"]}"
puts "País      : #{item["country"]}"
puts "Discogs ID: #{item["id"]}"
puts "Imagem    : #{item["thumb"]}"
puts

puts "Obtendo detalhes..."
puts

detalhes = discogs.release(item["id"])

puts "=" * 80
puts "DETALHES"
puts "=" * 80

puts "Título : #{detalhes["title"]}"
puts "Ano    : #{detalhes["year"]}"
puts "País   : #{detalhes["country"]}"

if detalhes["artists"]
  puts "\nArtistas:"
  detalhes["artists"].each do |artist|
    puts " - #{artist["name"]}"
  end
end

if detalhes["labels"]
  puts "\nGravadoras:"
  detalhes["labels"].each do |label|
    puts " - #{label["name"]}"
  end
end

if detalhes["genres"]&.any?
  puts "\nGêneros:"
  puts detalhes["genres"].join(", ")
end

if detalhes["styles"]&.any?
  puts "\nEstilos:"
  puts detalhes["styles"].join(", ")
end

if detalhes["tracklist"]&.any?
  puts "\nFaixas:"
  detalhes["tracklist"].each do |track|
    puts "#{track["position"]} - #{track["title"]} (#{track["duration"]})"
  end
end