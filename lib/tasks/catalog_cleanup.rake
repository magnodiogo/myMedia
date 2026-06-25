namespace :catalog do
  namespace :cleanup do
    desc "Remove catalog data while preserving users and artists"
    task keep_users_and_artists: :environment do
      CatalogCleanupTask.new(
        dry_run: ENV["DRY_RUN"].to_s == "1",
        confirmed: ENV["CONFIRM"].to_s == "1",
        reset_sequences: ENV.fetch("RESET_SEQUENCES", "1").to_s == "1"
      ).run
    end
  end
end

class CatalogCleanupTask
  PRESERVED_ATTACHMENT_TYPES = %w[Artist User].freeze
  PRESERVED_SLUG_TYPES = %w[Artist User].freeze

  DELETE_STEPS = [
    ["Track credits", -> { TrackCredit }],
    ["Tracks", -> { Track }],
    ["User media", -> { UserMedia }],
    ["Album credits", -> { AlbumCredit }],
    ["Album genre links", -> { AlbumGenreLink }],
    ["Album style links", -> { AlbumStyleLink }],
    ["Album recording location links", -> { AlbumRecordingLocationLink }],
    ["Media genre links", -> { MediaGenreLink }],
    ["Media style links", -> { MediaStyleLink }],
    ["Media recording location links", -> { MediaRecordingLocationLink }],
    ["Media", -> { Media }],
    ["Albums", -> { Album }],
    ["Credit people", -> { CreditPerson }],
    ["Media genres", -> { MediaGenre }],
    ["Media styles", -> { MediaStyle }],
    ["Recording locations", -> { RecordingLocation }],
    ["Media types", -> { MediaType }],
    ["Notifications", -> { Notification }]
  ].freeze

  def initialize(dry_run:, confirmed:, reset_sequences:)
    @dry_run = dry_run
    @confirmed = confirmed
    @reset_sequences = reset_sequences
  end

  def run
    say "Catalog cleanup: keep users and artists#{dry_run? ? ' (dry run)' : ''}."
    say "Preserving #{User.count} users and #{Artist.count} artists."

    unless dry_run? || confirmed?
      say "Nothing deleted. Run with CONFIRM=1 to apply this cleanup."
      print_counts
      return
    end

    ActiveRecord::Base.transaction do
      cleanup_active_storage
      cleanup_friendly_id_slugs
      delete_catalog_records
      reset_pk_sequences if reset_sequences? && !dry_run?

      raise ActiveRecord::Rollback if dry_run?
    end

    say dry_run? ? "Dry run finished. No data was deleted." : "Cleanup finished."
    say "Remaining: #{User.count} users and #{Artist.count} artists."
  end

  private

  def cleanup_active_storage
    attachment_scope = ActiveStorage::Attachment.where.not(record_type: PRESERVED_ATTACHMENT_TYPES)
    blob_ids = attachment_scope.distinct.pluck(:blob_id)
    preserved_blob_ids = ActiveStorage::Attachment
      .where(record_type: PRESERVED_ATTACHMENT_TYPES, blob_id: blob_ids)
      .distinct
      .pluck(:blob_id)
    removable_blob_ids = blob_ids - preserved_blob_ids

    report_or_delete("Active Storage attachments", attachment_scope)
    report_or_delete("Active Storage variants", ActiveStorage::VariantRecord.where(blob_id: removable_blob_ids))

    orphan_blob_scope = ActiveStorage::Blob.where.not(
      id: ActiveStorage::Attachment.select(:blob_id)
    )
    if removable_blob_ids.any?
      orphan_blob_scope = orphan_blob_scope.or(ActiveStorage::Blob.where(id: removable_blob_ids))
    end
    report_or_delete("Active Storage orphan blobs", orphan_blob_scope)
  end

  def cleanup_friendly_id_slugs
    report_or_delete(
      "Friendly slugs except users/artists",
      FriendlyId::Slug.where.not(sluggable_type: PRESERVED_SLUG_TYPES)
    )
  end

  def delete_catalog_records
    DELETE_STEPS.each do |label, model_proc|
      report_or_delete(label, model_proc.call.all)
    end
  end

  def report_or_delete(label, scope)
    count = scope.count
    say "  #{label}: #{dry_run? ? 'would delete' : 'deleted'} #{count}"
    scope.delete_all unless dry_run? || count.zero?
  end

  def print_counts
    say "Current removable records:"
    cleanup_counts.each do |label, count|
      say "  #{label}: #{count}"
    end
  end

  def cleanup_counts
    counts = DELETE_STEPS.map { |label, model_proc| [label, model_proc.call.count] }
    counts.unshift([
      "Friendly slugs except users/artists",
      FriendlyId::Slug.where.not(sluggable_type: PRESERVED_SLUG_TYPES).count
    ])
    counts.unshift([
      "Active Storage attachments except users/artists",
      ActiveStorage::Attachment.where.not(record_type: PRESERVED_ATTACHMENT_TYPES).count
    ])
    counts
  end

  def reset_pk_sequences
    tables = DELETE_STEPS.map { |_label, model_proc| model_proc.call.table_name }
    tables += %w[
      active_storage_attachments
      active_storage_blobs
      active_storage_variant_records
      friendly_id_slugs
    ]

    tables.uniq.each do |table|
      ActiveRecord::Base.connection.reset_pk_sequence!(table)
    rescue NotImplementedError
      nil
    end
  end

  def dry_run?
    @dry_run
  end

  def confirmed?
    @confirmed
  end

  def reset_sequences?
    @reset_sequences
  end

  def say(message)
    puts message
    Rails.logger.info("[CatalogCleanupTask] #{message}")
  end
end
