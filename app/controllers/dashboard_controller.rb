class DashboardController < ApplicationController
  def index
    @total_media = current_user.media.count
    @total_types = MediaType.count
    @total_artists = Artist.joins(media: :user_media).where(user_media: { user_id: current_user.id }).distinct.count

    # Group by name and count only the current user's media items
    @media_types_with_count = {}
    MediaType.all.each do |mt|
      count = current_user.user_media.joins(:media).where(media: { media_type_id: mt.id }).count
      @media_types_with_count[[mt.id, mt.name]] = count
    end

    @latest_media = current_user.media.includes(:media_type).order(created_at: :desc).limit(5)
  end
end
