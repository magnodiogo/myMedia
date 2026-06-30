require "test_helper"

class CreditPersonMetadataJobTest < ActiveJob::TestCase
  test "enqueues metadata loading job on credit person creation" do
    assert_enqueued_with(job: CreditPersonMetadataJob) do
      CreditPerson.create!(name: "Test Job Person")
    end
  end

  test "performs metadata loading" do
    person = CreditPerson.create!(name: "Test Job Person 2")
    called = false

    CreditPerson.define_method(:load_external_data_stubbed) do
      called = true
      { success: true }
    end

    CreditPerson.alias_method :original_load_external_data, :load_external_data
    CreditPerson.alias_method :load_external_data, :load_external_data_stubbed

    begin
      CreditPersonMetadataJob.perform_now(person)
      assert called
    ensure
      CreditPerson.alias_method :load_external_data, :original_load_external_data
      CreditPerson.remove_method :load_external_data_stubbed
      # Avoid warnings if they were not created
      CreditPerson.remove_method :original_load_external_data rescue nil
    end
  end
end
