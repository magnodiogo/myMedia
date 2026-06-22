require "base64"

module Api
  module V1
    class UserMediaController < ApiController
      def index
        @user_media = current_user.user_media.includes(:media)

        data = @user_media.map do |user_medium|
          m = user_medium.media
          # Use the latest updated timestamp between the collection record and the core media record
          updated_at = [user_medium.updated_at, m.updated_at].max

          {
            id: user_medium.id,
            media_id: m.id,
            updated_at: updated_at
          }
        end

        render json: data, status: :ok
      end

      def show
        user_medium = current_user.user_media.includes(media: [:artist, :media_type]).find(params[:id])
        m = user_medium.media
        cover_base64 = nil

        if m.cover_image.attached?
          begin
            blob_content = m.cover_image.download
            content_type = m.cover_image.content_type
            cover_base64 = "data:#{content_type};base64,#{Base64.strict_encode64(blob_content)}"
          rescue => e
            Rails.logger.error("Failed to base64 encode cover image for media #{m.id}: #{e.message}")
          end
        end

        data = {
          id: user_medium.id,
          notes: user_medium.notes,
          purchase_location: user_medium.purchase_location,
          price_paid: user_medium.price_paid,
          currency: user_medium.currency,
          purchase_date: user_medium.purchase_date,
          physical_location: user_medium.physical_location,
          condition: user_medium.condition,
          sleeve_condition: user_medium.sleeve_condition,
          is_signed: user_medium.is_signed,
          is_sealed: user_medium.is_sealed,
          edition_notes: user_medium.edition_notes,
          created_at: user_medium.created_at,
          updated_at: user_medium.updated_at,
          media: {
            id: m.id,
            title: m.title,
            release_year: m.release_year,
            catalog_number: m.catalog_number,
            barcode: m.barcode,
            slug: m.slug,
            artist: {
              id: m.artist.id,
              name: m.artist.name
            },
            media_type: {
              id: m.media_type.id,
              name: m.media_type.name
            },
            cover_image_base64: cover_base64
          }
        }

        render json: data, status: :ok
      end
    end
  end
end
