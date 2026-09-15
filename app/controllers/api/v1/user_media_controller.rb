require "base64"

module Api
  module V1
    class UserMediaController < ApiController
      def index
        @user_media = current_user.user_media.includes(:media)

        data = @user_media.map do |user_medium|
          serialize_sync_record(user_medium)
        end

        response.headers["X-Sync-Server-Time"] = Time.current.iso8601(6)
        render json: data, status: :ok
      end

      def changes
        since = parse_sync_time(params[:since])
        scope = current_user.user_media.includes(:media)
        scope = scope.select { |user_medium| sync_timestamp_for(user_medium) > since } if since

        server_time = Time.current.iso8601(6)
        response.headers["X-Sync-Server-Time"] = server_time

        render json: {
          server_time: server_time,
          changed: scope.map { |user_medium| serialize_sync_record(user_medium) },
          deleted_ids: []
        }, status: :ok
      end

      def album_info
        user_medium = current_user.user_media
                                  .includes(media: [
                                    :media_genres,
                                    :media_styles,
                                    :recording_locations,
                                    album: [:media_genres, :media_styles, :recording_locations]
                                  ])
                                  .find(params[:id])
        m = user_medium.media
        album = m.album

        render json: {
          summary: album&.summary.presence || m.info,
          duration: album&.formatted_duration.presence || m.formatted_duration,
          genres: (album&.media_genres.presence || m.media_genres).map { |genre| serialize_named_record(genre) },
          styles: (album&.media_styles.presence || m.media_styles).map { |style| serialize_named_record(style) },
          recording_locations: (album&.recording_locations.presence || m.recording_locations).map { |location| serialize_named_record(location) },
          album: album && {
            id: album.id,
            title: album.title,
            release_year: album.release_year,
            original_release_date: album.original_release_date,
            album_type: album.album_type,
            metadata_status: album.metadata_status
          }
        }, status: :ok
      end

      def collection
        user_medium = current_user.user_media.find(params[:id])

        render json: {
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
          updated_at: user_medium.updated_at
        }, status: :ok
      end

      def credits
        user_medium = current_user.user_media
                                  .includes(media: [
                                    { album: { album_credits: :credit_person } },
                                    { album_credits: :credit_person }
                                  ])
                                  .find(params[:id])
        m = user_medium.media
        display_credits = m.album&.album_credits.presence || m.album_credits
        credits = display_credits.includes(:credit_person).order(:person_name, :role)

        render json: {
          credits: credits.map { |credit| serialize_album_credit(credit) },
          grouped: credits.group_by(&:credit_category).transform_values do |group|
            group.map { |credit| serialize_album_credit(credit) }
          end
        }, status: :ok
      end

      def tracks
        user_medium = current_user.user_media
                                  .includes(media: [
                                    { tracks: :track_credits },
                                    { album: { tracks: :track_credits } }
                                  ])
                                  .find(params[:id])
        m = user_medium.media
        display_tracks = m.tracks.includes(:track_credits).presence || m.album&.display_tracks || []

        render json: {
          tracks: display_tracks.sort_by(&:display_order_key).map { |track| serialize_track(track) }
        }, status: :ok
      end

      def track_lyrics
        user_medium = current_user.user_media
                                  .includes(media: [:tracks, { album: :tracks }])
                                  .find(params[:id])
        m = user_medium.media
        display_tracks = m.tracks.presence || m.album&.display_tracks || []
        track = display_tracks.detect { |item| item.id == params[:track_id].to_i }

        unless track
          render json: { error: "Track not found" }, status: :not_found
          return
        end

        render json: {
          track_id: track.id,
          title: track.title,
          lyrics: track.lyrics.to_s.strip.presence
        }, status: :ok
      end

      def show
        user_medium = current_user.user_media.includes(media: [:artist, :media_type]).find(params[:id])
        render json: serialize_user_medium(user_medium), status: :ok
      end

      def update
        user_medium = current_user.user_media.find(params[:id])

        if user_medium.update(user_media_params)
          render json: serialize_user_medium(user_medium.reload), status: :ok
        else
          render json: { error: user_medium.errors.full_messages.to_sentence.presence || "Could not update this media." },
                 status: :unprocessable_entity
        end
      end

      private

      def serialize_sync_record(user_medium)
        {
          id: user_medium.id,
          media_id: user_medium.media_id,
          updated_at: sync_timestamp_for(user_medium).iso8601(6),
          user_media_updated_at: user_medium.updated_at&.iso8601(6),
          media_updated_at: user_medium.media&.updated_at&.iso8601(6)
        }
      end

      def sync_timestamp_for(user_medium)
        [user_medium.updated_at, user_medium.media&.updated_at].compact.max
      end

      def parse_sync_time(value)
        return nil if value.blank?

        Time.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def user_media_params
        params.permit(
          :notes,
          :purchase_location,
          :price_paid,
          :currency,
          :purchase_date,
          :physical_location,
          :condition,
          :sleeve_condition,
          :is_signed,
          :is_sealed,
          :edition_notes
        )
      end

      def serialize_user_medium(user_medium)
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

        {
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
          updated_at: sync_timestamp_for(user_medium)&.iso8601(6),
          user_media_updated_at: user_medium.updated_at&.iso8601(6),
          media_updated_at: m.updated_at&.iso8601(6),
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
      end

      def serialize_named_record(record)
        {
          id: record.id,
          name: record.name
        }
      end

      def serialize_album_credit(credit)
        {
          id: credit.id,
          person_name: credit.person_name,
          role: credit.role,
          category: credit.credit_category,
          source: credit.source,
          credit_person: credit.credit_person && {
            id: credit.credit_person.id,
            name: credit.credit_person.name
          }
        }
      end

      def serialize_track(track)
        {
          id: track.id,
          title: track.title,
          track_number: track.track_number,
          disc_number: track.disc_number,
          position: track.position,
          duration: track.duration,
          lyrics_available: track.lyrics.present?,
          credits: track.track_credits.order(:name, :function).map do |credit|
            {
              id: credit.id,
              name: credit.name,
              function: credit.function,
              category: AlbumCredit.category_for_role(credit.function)
            }
          end
        }
      end
    end
  end
end
