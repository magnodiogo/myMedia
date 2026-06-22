class UserMedia < ApplicationRecord
  belongs_to :user
  belongs_to :media

  CONDITIONS = [
    ["Mint (M)", "M"],
    ["Near Mint (NM)", "NM"],
    ["Very Good Plus (VG+)", "VG+"],
    ["Very Good (VG)", "VG"],
    ["Good Plus (G+)", "G+"],
    ["Good (G)", "G"],
    ["Fair (F)", "F"],
    ["Poor (P)", "P"]
  ].freeze

  CURRENCIES = ["BRL", "USD", "EUR", "GBP"].freeze
end
