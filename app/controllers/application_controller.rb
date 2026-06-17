class ApplicationController < ActionController::Base
  helper_method :current_user

  def current_user
    @current_user ||= begin
      if session[:user_id]
        User.find_by(id: session[:user_id])
      end
    end
    @current_user ||= User.first
  end
end
