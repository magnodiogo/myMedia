class AlbumReleasesController < ApplicationController
  before_action :require_admin!, except: %i[ add_to_collection ]
  before_action :set_album
  before_action :set_album_release, only: %i[ edit update destroy try_load_cover add_to_collection ]

  def new
    @album_release = @album.album_releases.new
  end

  def create
    @album_release = @album.album_releases.new(album_release_params)

    if @album_release.save
      redirect_to album_path(@album), notice: "Album release was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @album_release.update(album_release_params)
      redirect_to album_path(@album), notice: "Album release was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @album_release.destroy
    redirect_to album_path(@album), notice: "Album release was successfully deleted."
  end

  def try_load_cover
    if @album_release.try_load_cover!
      redirect_to album_path(@album), notice: "Release cover loaded successfully."
    else
      redirect_to album_path(@album), alert: "Could not find a cover for this release."
    end
  end

  def add_to_collection
    unless @album_release.physical?
      redirect_to album_path(@album), alert: "Digital releases cannot be added to a physical collection."
      return
    end

    medium = @album_release.to_media
    user_medium = current_user.user_media.find_or_initialize_by(media: medium)

    if user_medium.persisted?
      redirect_to media_path(medium), notice: "This release is already in your collection."
    elsif user_medium.save
      redirect_to media_path(medium), notice: "Release added to your collection."
    else
      redirect_to album_path(@album), alert: user_medium.errors.full_messages.to_sentence.presence || "Could not add this release to your collection."
    end
  end

  private

  def set_album
    @album = Album.friendly.find(params[:album_id])
  end

  def set_album_release
    @album_release = @album.album_releases.find(params[:id])
  end

  def album_release_params
    params.require(:album_release).permit(
      :title, :release_year, :format, :label, :catalog_number,
      :allmusic_url, :info, :position, :cover_image
    )
  end
end
