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

  def require_admin!
    unless current_user&.admin?
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Only administrator users can perform this action." }
        format.json { render json: { error: "Only administrator users can perform this action." }, status: :forbidden }
      end
    end
  end
end
