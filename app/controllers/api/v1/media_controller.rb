require "base64"

module Api
  module V1
    class MediaController < ApiController
      def barcode_lookup
        barcode = params[:barcode].to_s.gsub(/[-\s]/, "")

        if barcode.blank?
          render json: { error: "Barcode is required" }, status: :bad_request
          return
        end

        result = BarcodeLookupService.lookup(barcode)

        if result.present?
          render json: result.merge(barcode: barcode), status: :ok
        else
          render json: { error: "Barcode not found online" }, status: :not_found
        end
      end

      def import_and_add
        barcode = params[:barcode].to_s.gsub(/[-\s]/, "")
        media_type_id = params[:media_type_id].presence || MediaType.first&.id
        medium = barcode.present? ? Media.find_by(barcode: barcode) : nil
        medium ||= Media.new

        if medium.new_record?
          medium.assign_attributes(
            media_type_id: media_type_id,
            title: params[:title],
            artist: params[:artist],
            release_year: params[:release_year],
            catalog_number: params[:catalog_number],
            barcode: barcode.presence,
            cover_url: params[:cover_url]
          )
        elsif params[:cover_url].present? && !medium.cover_image.attached?
          medium.cover_url = params[:cover_url]
        end

        unless medium.save
          render json: { error: medium.errors.full_messages.to_sentence.presence || "Could not import this media." },
                 status: :unprocessable_entity
          return
        end

        user_medium = current_user.user_media.find_or_initialize_by(media: medium)
        already_owned = user_medium.persisted?
        user_medium.assign_attributes(user_media_params) unless already_owned

        unless already_owned || user_medium.save
          render json: { error: user_medium.errors.full_messages.to_sentence.presence || "Could not add this media." },
                 status: :unprocessable_entity
          return
        end

        render json: {
          user_media: serialize_user_medium(user_medium),
          already_owned: already_owned,
          message: already_owned ? "This media is already in your collection." : "Media added to your collection."
        }, status: already_owned ? :ok : :created
      end

      private

      def user_media_params
        source = params[:user_media].present? ? params.require(:user_media) : params
        source.permit(
          :notes, :purchase_location, :price_paid, :currency,
          :purchase_date, :physical_location, :condition, :sleeve_condition,
          :is_signed, :is_sealed, :edition_notes
        )
      end

      def serialize_user_medium(user_medium)
        medium = user_medium.media

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
          updated_at: user_medium.updated_at,
          media: {
            id: medium.id,
            title: medium.title,
            release_year: medium.release_year,
            catalog_number: medium.catalog_number,
            barcode: medium.barcode,
            slug: medium.slug,
            artist: {
              id: medium.artist.id,
              name: medium.artist.name
            },
            media_type: {
              id: medium.media_type.id,
              name: medium.media_type.name
            },
            cover_image_base64: attachment_base64(medium.cover_image)
          }
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
