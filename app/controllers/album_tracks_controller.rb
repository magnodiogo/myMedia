class AlbumTracksController < ApplicationController
  before_action :set_album
  before_action :set_track

  def show_lyrics
    render "tracks/show_lyrics"
  end

  private

  def set_album
    @album = Album.friendly.find(params[:album_id])
  end

  def set_track
    @track = @album.tracks.find(params[:id])
  end
end
