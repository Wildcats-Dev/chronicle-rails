FactoryBot.define do
  factory :admin_user, class: 'Chronicle::AdminUser' do
    email      { Faker::Internet.unique.email }
    password   { 'password123' }
    auth_token { SecureRandom.hex(16) }
    name       { Faker::Name.name }
    role       { Chronicle::AdminUser::A1 }
  end
end
