class ArtistsController < ApplicationController
  before_action :set_artist, only: %i[ show edit update destroy update_wiki update_photo ]
  before_action :require_admin!, only: %i[ new create edit update destroy update_wiki update_photo ]

  def index
    @artists = Artist.all.order(:name)
  end

  def show
    @media = @artist.media.includes(:media_type).order(title: :asc)
  end

  def new
    @artist = Artist.new
  end

  def edit
  end

  def create
    @artist = Artist.new(artist_params)
    if @artist.save
      redirect_to artists_path, notice: "Artist was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @artist.update(artist_params)
      redirect_to artists_path, notice: "Artist was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @artist.destroy
      redirect_to artists_path, notice: "Artist was successfully destroyed."
    else
      redirect_to artists_path, alert: @artist.errors.full_messages.to_sentence
    end
  end

  def update_wiki
    if @artist.update_bio_from_wikipedia
      redirect_to edit_artist_path(@artist), notice: "Artist biography successfully updated from Wikipedia."
    else
      redirect_to edit_artist_path(@artist), alert: "Could not find a Wikipedia biography for this artist."
    end
  end

  def update_photo
    if @artist.update_photo_from_wikipedia
      redirect_to edit_artist_path(@artist), notice: "Artist photo successfully updated from Wikipedia."
    else
      redirect_to edit_artist_path(@artist), alert: "Could not find a Wikipedia photo for this artist."
    end
  end

  private

  def set_artist
    @artist = Artist.friendly.find(params[:id])
  end

  def artist_params
    params.require(:artist).permit(:name, :bio, :photo)
  end
end
