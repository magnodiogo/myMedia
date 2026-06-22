module Api
  module V1
    class AuthController < ApiController
      skip_before_action :authenticate_api_user!, only: [:login]

      def login
        user = User.find_by(email: params[:email])

        if user&.is_a?(CommonUser) && user.valid_password?(params[:password])
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            user: {
              id: user.id,
              name: user.name,
              email: user.email,
              type: user.type,
              subscription_tier: user.subscription_tier
            }
          }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def me
        render json: {
          user: {
            id: current_user.id,
            name: current_user.name,
            email: current_user.email,
            type: current_user.type,
            subscription_tier: current_user.subscription_tier
          }
        }, status: :ok
      end
    end
  end
end
