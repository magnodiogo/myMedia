require "base64"

module Api
  module V1
    class ArtistsController < ApiController
      def show
        artist = Artist.with_attached_photo.with_attached_banner.find(params[:id])
        albums = artist.albums
        media = artist.media

        render json: {
          id: artist.id,
          name: artist.name,
          bio: artist.bio,
          fun_facts: artist.fun_facts,
          album_count: albums.count,
          edition_count: media.count,
          styles: artist.albums.joins(:media_styles).distinct.order("media_styles.name").pluck("media_styles.name"),
          photo_base64: attachment_base64(artist.photo),
          banner_base64: attachment_base64(artist.banner)
        }, status: :ok
      end

      def discography
        artist = Artist.find(params[:id])
        query = params[:q].to_s.strip
        limit = [[params[:limit].to_i, 1].max, 50].min
        offset = [params[:offset].to_i, 0].max
        albums = artist.albums
                       .includes(
                         :media,
                         :media_styles,
                         { cover_image_attachment: :blob },
                         album_releases: [:media_type, { cover_image_attachment: :blob }]
                       )
                       .order(:release_year, :title)

        if query.present?
          albums = albums.where("albums.title ILIKE ?", "%#{query}%")
        end

        total_count = albums.count
        paginated_albums = albums.limit(limit).offset(offset)

        render json: {
          albums: paginated_albums.map { |album| serialize_album(album) },
          pagination: {
            total_count: total_count,
            limit: limit,
            offset: offset,
            has_more: offset + paginated_albums.size < total_count
          }
        }, status: :ok
      end

      def add_release_to_collection
        artist = Artist.find(params[:id])
        release = artist.albums.joins(:album_releases)
                        .merge(AlbumRelease.where(id: params[:release_id]))
                        .first
                        &.album_releases
                        &.find(params[:release_id])

        unless release
          render json: { error: "Release not found" }, status: :not_found
          return
        end

        unless release.physical?
          render json: { error: "Digital releases cannot be added to a physical collection." }, status: :unprocessable_entity
          return
        end

        medium = release.to_media
        user_medium = current_user.user_media.find_or_initialize_by(media: medium)
        already_owned = user_medium.persisted?

        if already_owned || user_medium.save
          render json: {
            user_media_id: user_medium.id,
            media_id: medium.id,
            already_owned: already_owned,
            message: already_owned ? "This release is already in your collection." : "Release added to your collection."
          }, status: :ok
        else
          render json: { error: user_medium.errors.full_messages.to_sentence.presence || "Could not add this release." },
                 status: :unprocessable_entity
        end
      end

      private

      def serialize_album(album)
        releases = album.album_releases.sort_by { |release| [release.release_year || 0, release.position || 0, release.title] }

        {
          id: album.id,
          title: album.title,
          release_year: album.release_year,
          album_type: album.album_type,
          metadata_status: album.metadata_status,
          release_count: releases.size,
          owned: album.media.any? { |medium| current_user.media.exists?(medium.id) },
          cover_image_base64: attachment_base64(album.display_cover),
          releases: releases.map { |release| serialize_release(release) }
        }
      end

      def serialize_release(release)
        medium = release.media.first
        owned = medium.present? && current_user.media.exists?(medium.id)

        {
          id: release.id,
          title: release.title,
          release_year: release.release_year,
          media_type: release.media_type&.name,
          label: release.label,
          catalog_number: release.catalog_number,
          physical: release.physical?,
          owned: owned
        }
      end

      def attachment_base64(attachment)
        return nil unless attachment&.attached?

        "data:#{attachment.content_type};base64,#{Base64.strict_encode64(attachment.download)}"
      rescue => e
        Rails.logger.error("Failed to base64 encode attachment: #{e.message}")
        nil
      end
    end
  end
end
