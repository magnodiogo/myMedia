class DashboardController < ApplicationController
  def index
    if current_user.admin?
      @total_users = User.count
      @total_common_users = CommonUser.count
      @total_admin_users = AdminUser.count
      @total_unique_media = Media.count
      @total_user_media = UserMedia.count
      @total_artists = Artist.count
      @total_types = MediaType.count

      @premium_monthly_count = User.where(subscription_tier: "paid_monthly").count
      @premium_yearly_count = User.where(subscription_tier: "paid_yearly").count
      @premium_users_count = @premium_monthly_count + @premium_yearly_count
      @free_users_count = User.where(subscription_tier: "free").count

      monthly_price = SystemSetting.monthly_subscription_price
      yearly_price = SystemSetting.yearly_subscription_price
      
      @monthly_revenue_estimation = (@premium_monthly_count * monthly_price) + (@premium_yearly_count * (yearly_price / 12.0))
      @annual_revenue_estimation = @monthly_revenue_estimation * 12

      # Last user who added a media
      @last_addition = UserMedia.includes(:user, :media).order(created_at: :desc).first
      @last_user_added = @last_addition&.user
      @last_media_added = @last_addition&.media

      # Top collector
      @top_user = User.joins(:user_media)
                      .group('users.id')
                      .order('count(user_media.id) DESC')
                      .first
      @top_user_count = @top_user ? @top_user.user_media.count : 0

      # Top active users (collectors)
      @top_users = User.left_outer_joins(:user_media)
                       .group('users.id')
                       .order('count(user_media.id) DESC')
                       .limit(5)
                       .select('users.*, count(user_media.id) as media_count')

      # Recent additions across the app
      @recent_additions = UserMedia.includes(:user, media: [:artist, :media_type])
                                   .order(created_at: :desc)
                                   .limit(5)

      # Format distribution (company wide)
      @media_types_with_count = {}
      MediaType.all.each do |mt|
        count = UserMedia.joins(:media).where(media: { media_type_id: mt.id }).count
        @media_types_with_count[[mt.id, mt.name]] = count
      end

      render :admin_index
    else
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
      @latest_artists = Artist.joins(media: :user_media).where(user_media: { user_id: current_user.id }).distinct.order("artists.id DESC").limit(5)
    end
  end
end
