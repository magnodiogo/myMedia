class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:switch_user]

  def switch_user
    user = User.find(params[:user_id])
    sign_in(user)
    redirect_back fallback_location: root_path
  end
end
