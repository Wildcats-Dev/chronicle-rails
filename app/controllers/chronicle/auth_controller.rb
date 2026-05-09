module Chronicle
  class AuthController < ApplicationController
    def login
      email    = params.require(:email)
      password = params.require(:password)

      admin_user = AdminUser.find_by(email: email)
      raise NotFoundError, 'User not found' unless admin_user

      if admin_user.authenticate(password)
        render json: { admin_user: admin_user.slice(:id, :name, :email, :auth_token) }, status: :ok
      else
        render json: { error: 'Invalid email or password' }, status: :unauthorized
      end
    end
  end
end
