class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :load_preferences
  before_action :detect_device

  layout :determine_layout

  def determine_layout
    if devise_controller?
      "application"
    elsif current_user&.admin?
      "admin"
    else
      "application"
    end
  end

  def detect_device
    if params[:variant] == "mobile"
      request.variant = :mobile
    elsif params[:variant] == "desktop"
      request.variant = nil
    elsif mobile_device?
      request.variant = :mobile
    end
  end

  def load_preferences
    if current_user
      @theme = current_user.theme.presence || "dark"
      @sidebar_collapsed = current_user.sidebar_collapsed
      @view_preference = current_user.view_preference.presence || "detailed"
      @media_card_size = current_user.media_card_size || 180

      @collection_count = current_user.user_media.count
      @collection_limit = SystemSetting.free_user_media_limit
    else
      @theme = cookies[:theme] || "dark"
      @sidebar_collapsed = cookies[:sidebar_collapsed] == "true"
      @view_preference = cookies[:view_preference] || "detailed"
      @media_card_size = cookies[:media_card_size] || 180
    end

    # Fallback for mobile devices on first load
    if cookies[:sidebar_collapsed].nil? && !current_user
      if mobile_device?
        @sidebar_collapsed = true
      end
    end
  end

  def mobile_device?
    user_agent = request.user_agent.to_s.downcase
    user_agent =~ /mobile|android|iphone|ipad|iemobile|opera mini/
  end

  def require_admin!
    unless current_user&.admin?
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Only administrator users can perform this action." }
        format.json { render json: { error: "Only administrator users can perform this action." }, status: :forbidden }
      end
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end
end
