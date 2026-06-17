class SessionsController < ApplicationController
  def switch_user
    session[:user_id] = params[:user_id]
    redirect_back fallback_location: root_path
  end
end
