module Chronicle
  class ApplicationController < ActionController::API
    rescue_from BaseError do |e|
      render json: { error: e.message }, status: e.status_code
    end

    rescue_from ActionController::ParameterMissing do |e|
      render json: { error: e.message }, status: :bad_request
    end

    private

    def authenticate_admin_user!
      auth_token = request.headers['X-Admin-Auth-Token']
      raise ForbiddenError, 'Missing admin auth token' unless auth_token

      admin_user = AdminUser.find_by(auth_token: auth_token)
      raise ForbiddenError, 'Invalid admin auth token' unless admin_user

      @current_admin_user = admin_user
    end
  end
end
