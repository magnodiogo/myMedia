class CollectionProgressAnalytics
  def self.most_complete_artists(limit: 10, user: nil)
    artist_progress(user: user)
      .select { |entry| entry[:progress][:total_count].positive? }
      .sort_by { |entry| [-entry[:progress][:percentage], entry[:artist].name] }
      .first(limit)
  end

  def self.incomplete_artists(limit: 10, user: nil)
    artist_progress(user: user)
      .select { |entry| entry[:progress][:total_count].positive? && entry[:progress][:percentage] < 100.0 }
      .sort_by { |entry| [entry[:progress][:percentage], entry[:artist].name] }
      .first(limit)
  end

  def self.completed_collection_lists(user: nil)
    CollectionList.ordered.select do |collection_list|
      progress = CollectionProgressCalculator.for_collection_list(collection_list, user: user)
      progress[:total_count].positive? && progress[:percentage] == 100.0
    end
  end

  def self.progress_for_artist_eras(artist, user: nil)
    artist.artist_eras.map do |artist_era|
      {
        artist_era: artist_era,
        progress: CollectionProgressCalculator.for_artist_era(artist_era, user: user)
      }
    end
  end

  def self.artist_progress(user: nil)
    Artist.order(:name).map do |artist|
      {
        artist: artist,
        progress: CollectionProgressCalculator.for_artist(artist, user: user)
      }
    end
  end
end
