module Api
  module V1
    class ApiController < ActionController::API
      before_action :authenticate_api_user!

      def authenticate_api_user!
        header = request.headers["Authorization"]
        header = header.split(" ").last if header
        decoded = JsonWebToken.decode(header) if header

        if decoded && decoded[:user_id]
          @current_user = User.find_by(id: decoded[:user_id])
        end

        unless @current_user
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def current_user
        @current_user
      end
    end
  end
end
