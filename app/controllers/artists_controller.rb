class ArtistsController < ApplicationController
  before_action :set_artist, only: %i[ show edit update destroy ]
  before_action :require_admin!, only: %i[ new create edit update destroy ]

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

  private

  def set_artist
    @artist = Artist.friendly.find(params[:id])
  end

  def artist_params
    params.require(:artist).permit(:name, :bio, :photo)
  end
end
