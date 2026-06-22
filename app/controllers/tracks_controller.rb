class TracksController < ApplicationController
  before_action :set_media
  before_action :set_track, only: [:edit, :update, :destroy, :show_lyrics, :edit_lyrics, :update_lyrics]
  before_action :require_admin!, only: [:create, :edit, :update, :destroy, :edit_lyrics, :update_lyrics]

  def create
    @track = @media.tracks.build(track_params)

    respond_to do |format|
      if @track.save
        format.html { redirect_to media_path(@media), notice: "Track was successfully added." }
        format.turbo_stream
      else
        # In case of validation errors, we render a turbo stream to show errors or redirect
        format.html { redirect_to media_path(@media), alert: @track.errors.full_messages.to_sentence }
        format.turbo_stream
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
    end
  end

  def show_lyrics
    respond_to do |format|
      format.html
    end
  end

  def edit_lyrics
    respond_to do |format|
      format.html
    end
  end

  def update
    respond_to do |format|
      if @track.update(track_params)
        format.html { redirect_to media_path(@media), notice: "Track was successfully updated." }
        format.turbo_stream
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@track), partial: "tracks/form", locals: { media: @media, track: @track }) }
      end
    end
  end

  def update_lyrics
    respond_to do |format|
      if @track.update(track_params)
        format.html { redirect_to media_path(@media), notice: "Lyrics was successfully updated." }
        format.turbo_stream
      else
        format.html { render :edit_lyrics, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("lyrics_frame", template: "tracks/edit_lyrics") }
      end
    end
  end

  def destroy
    @track.destroy

    respond_to do |format|
      format.html { redirect_to media_path(@media), notice: "Track was successfully removed." }
      format.turbo_stream
    end
  end

  private

  def set_media
    @media = Media.friendly.find(params[:media_id])
  end

  def set_track
    @track = @media.tracks.find(params[:id])
  end

  def track_params
    params.require(:track).permit(:title, :track_number, :duration, :lyrics)
  end
end

