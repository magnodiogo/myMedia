class DashboardController < ApplicationController
  def index
    @total_media = Media.count
    @total_types = MediaType.count
    # Group by name and count, filling in zeroes if needed could be done in ruby
    # Let's count media for each type
    @media_types_with_count = MediaType.left_joins(:media).group(:id, :name).count("media.id")
    @latest_media = Media.includes(:media_type).order(created_at: :desc).limit(5)
  end
end
