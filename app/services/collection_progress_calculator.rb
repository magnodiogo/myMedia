class CollectionProgressCalculator
  def self.for_artist(artist, user: nil)
    new(user: user).calculate(artist.media)
  end

  def self.for_artist_era(artist_era, user: nil)
    new(user: user).calculate(artist_era.media_scope)
  end

  def self.for_collection_list(collection_list, user: nil)
    new(user: user).calculate(collection_list.media)
  end

  def initialize(user: nil)
    @user = user
  end

  def calculate(media_scope)
    target_media = media_scope.distinct
    owned_media = owned_media_scope(target_media)
    total_count = target_media.count
    owned_count = owned_media.count
    missing_media = missing_media_scope(target_media, owned_media)

    {
      total_count: total_count,
      owned_count: owned_count,
      percentage: percentage(owned_count, total_count),
      missing_count: total_count - owned_count,
      missing_media: missing_media
    }
  end

  private

  attr_reader :user

  def owned_media_scope(media_scope)
    # TODO: Revisit this when myMedia separates catalog items from owned physical copies more explicitly.
    return media_scope if user.blank?

    media_scope.joins(:user_media).where(user_media: { user_id: user.id }).distinct
  end

  def missing_media_scope(target_media, owned_media)
    target_media.where.not(id: owned_media.select(:id))
  end

  def percentage(owned_count, total_count)
    return 0.0 if total_count.zero?

    ((owned_count.to_f / total_count) * 100).round(1)
  end
end
