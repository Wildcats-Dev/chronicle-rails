FactoryBot.define do
  factory :api_route, class: 'Chronicle::ApiRoute' do
    sequence(:path)  { |n| "/api/resource_#{n}" }
    http_method      { 'GET' }
    first_seen_at    { Time.current }
  end
end
