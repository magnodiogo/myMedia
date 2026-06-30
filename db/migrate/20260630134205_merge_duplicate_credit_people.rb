class MergeDuplicateCreditPeople < ActiveRecord::Migration[7.1]
  def up
    people = CreditPerson.all.to_a
    groups = people.group_by { |cp| ActiveSupport::Inflector.transliterate(cp.name.to_s).downcase.strip }

    groups.each do |key, group_people|
      next if group_people.size <= 1

      sorted = group_people.sort_by(&:id)
      canonical = sorted.first
      duplicates = sorted[1..-1]

      duplicates.each do |dup|
        # Re-assign album credits
        dup.album_credits.each do |credit|
          existing = canonical.album_credits.find_by(album_id: credit.album_id, role: credit.role)
          if existing
            credit.destroy
          else
            credit.update_columns(credit_person_id: canonical.id)
          end
        end

        # Merge fields if missing in canonical
        canonical.wikipedia_url ||= dup.wikipedia_url
        canonical.allmusic_url ||= dup.allmusic_url
        canonical.bio ||= dup.bio if canonical.bio.blank?
        canonical.birth_date ||= dup.birth_date
        canonical.birth_place ||= dup.birth_place
        canonical.death_date ||= dup.death_date
        canonical.death_place ||= dup.death_place
        
        # Merge photo if attached
        if dup.photo.attached? && !canonical.photo.attached?
          begin
            canonical.photo.attach(dup.photo.blob)
          rescue => e
            Rails.logger.warn "Failed to merge photo from CreditPerson #{dup.id} to #{canonical.id}: #{e.message}"
          end
        end

        dup.destroy
      end

      canonical.save! if canonical.changed?
    end
  end

  def down
    # Irreversible migration
  end
end
