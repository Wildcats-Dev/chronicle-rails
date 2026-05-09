module Chronicle
  class ApiLog < ApplicationRecord
    after_commit :sync_api_route, on: :create

    def get_hash
      hash = attributes

      klass = Chronicle.config.user_model

      hash['user'] = klass.find_by(id: user_id)&.basic_info if user_id.present? && klass.present?

      hash
    end

    private

    def sync_api_route
      return if api_endpoint.blank? || http_method.blank?
      return if ApiRoute.exists?(path: api_endpoint, http_method: http_method)

      ApiRoute.create!(path: api_endpoint, http_method: http_method, first_seen_at: created_at,
                       created_at: created_at, updated_at: created_at)
    end
  end
end
