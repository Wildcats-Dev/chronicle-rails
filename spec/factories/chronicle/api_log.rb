FactoryBot.define do
  factory :api_log, class: 'Chronicle::ApiLog' do
    user_id { nil }
    request_id { SecureRandom.uuid }
    device_os { 'iOS' }
    device_id { SecureRandom.hex(8) }
    device_type { 'mobile' }
    ip_address { Faker::Internet.ip_v4_address }
    http_method { 'GET' }
    api_endpoint { '/api/users' }
    http_status_code { 200 }
    response_time_ms { 150 }
    brand { 'Apple' }
    device_model_name { 'iPhone 14' }
    os_version { '16.0' }
    time_zone { 'UTC' }
    timestamp { Time.current }
    backend_version { '1.0.0' }
    client_version { '1.0.0' }
    path_params { {} }
    meta { {} }

    trait :android do
      device_os { 'Android' }
      brand { 'Samsung' }
      device_model_name { 'Galaxy S23' }
    end

    trait :post_request do
      http_method { 'POST' }
    end

    trait :error_response do
      http_status_code { 500 }
    end
  end
end
