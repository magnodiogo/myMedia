class CreditPersonMetadataJob < ApplicationJob
  queue_as :default

  def perform(credit_person)
    credit_person.load_external_data
  rescue => e
    Rails.logger.error("[CreditPersonMetadataJob] Failed to load external data for CreditPerson #{credit_person.id}: #{e.message}")
  end
end
