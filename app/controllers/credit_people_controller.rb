class CreditPeopleController < ApplicationController
  before_action :set_credit_person, only: %i[ show load_metadata update_wiki update_photo edit update ]
  before_action :require_admin!, only: %i[ load_metadata update_wiki update_photo edit update ]
  before_action :resize_uploaded_photo, only: %i[ update ]

  def show
    @credits = @credit_person.album_credits.includes(:album, media: [:album, :artist, :media_type, { cover_image_attachment: :blob }]).order(:credit_category, :role)
    @credits_by_media = @credits.select(&:media).group_by(&:media)
    @credits_by_album = @credits.select { |credit| credit.media.blank? && credit.album.present? }.group_by(&:album)
    @credits_by_category = @credits.group_by(&:credit_category)
  end

  def edit
  end

  def update
    if @credit_person.update(credit_person_params)
      redirect_to credit_person_path(@credit_person), notice: "Person was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_wiki
    if @credit_person.update_bio_from_wikipedia
      redirect_to credit_person_path(@credit_person), notice: "Credit person biography successfully updated from Wikipedia."
    else
      redirect_to credit_person_path(@credit_person), alert: "Could not find a Wikipedia biography for this credit person."
    end
  end

  def update_photo
    if @credit_person.update_photo_from_wikipedia
      redirect_to credit_person_path(@credit_person), notice: "Credit person photo successfully updated from Wikipedia."
    else
      redirect_to credit_person_path(@credit_person), alert: "Could not find a Wikipedia photo for this credit person."
    end
  end

  def load_metadata
    result = @credit_person.load_external_data

    loaded = []
    loaded << "AllMusic" if result[:allmusic]
    loaded << "Wikipedia biography" if result[:wikipedia_bio]
    loaded << "Wikipedia photo" if result[:wikipedia_photo]

    if result[:bio] || result[:photo] || loaded.any?
      notice = "Person data loaded"
      notice += " from #{loaded.to_sentence}" if loaded.any?
      notice += "."
      notice += " Photo updated." if result[:photo]
      redirect_to credit_person_path(@credit_person), notice: notice
    else
      alert = "Could not find new data for this person."
      alert += " #{result[:errors].join(' ')}" if result[:errors].any?
      redirect_to credit_person_path(@credit_person), alert: alert
    end
  end

  private

  def set_credit_person
    @credit_person = CreditPerson.friendly.find(params[:id])
  end

  def credit_person_params
    params.require(:credit_person).permit(
      :name, :bio, :wikipedia_url, :allmusic_url, :photo,
      :birth_date, :birth_place, :death_date, :death_place
    )
  end

  def resize_uploaded_photo
    if params.dig(:credit_person, :photo).present?
      uploaded_file = params[:credit_person][:photo]
      if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.present?
        system("mogrify -resize '600x600>' -strip #{uploaded_file.tempfile.path}")
      end
    end
  end
end
