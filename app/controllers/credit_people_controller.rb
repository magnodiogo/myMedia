class CreditPeopleController < ApplicationController
  before_action :set_credit_person, only: %i[ show update_wiki update_photo ]
  before_action :require_admin!, only: %i[ update_wiki update_photo ]

  def show
    @credits = @credit_person.album_credits.includes(media: [:album, :artist, :media_type]).order(:credit_category, :role)
    @credits_by_media = @credits.group_by(&:media)
    @credits_by_category = @credits.group_by(&:credit_category)
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

  private

  def set_credit_person
    @credit_person = CreditPerson.friendly.find(params[:id])
  end
end
