module RequestHelpers
  def headers
    { 'X-API-TOKEN' => Chronicle.config.api_token }.freeze
  end

  def admin_headers(admin_user)
    headers.merge('X-Admin-Auth-Token' => admin_user.auth_token)
  end

  def json(response)
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
