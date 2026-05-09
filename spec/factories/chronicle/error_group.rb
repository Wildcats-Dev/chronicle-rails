FactoryBot.define do
  factory :error_group, class: 'Chronicle::ErrorGroup' do
    project { 'chronicle' }
    sequence(:fingerprint) { |n| "fp#{n}" }
    source_type        { 'controller' }
    source_name        { 'users#index' }
    error_message      { 'Undefined method uuid for nil' }
    original_backtrace { "app/controllers/users_controller.rb:10:in 'show'" }
    cleaned_backtrace  { "app/controllers/users_controller.rb:10:in 'show'" }
    backend_version    { '1.0.0' }
    client_version     { '1.0.0' }
    status             { Chronicle::ErrorGroup::OPEN }
    first_seen_at      { Time.current }
    last_seen_at       { Time.current }
    occurrence_count   { 1 }
    jira_link          { nil }

    trait :open do
      status { Chronicle::ErrorGroup::OPEN }
    end

    trait :resolved do
      status { Chronicle::ErrorGroup::RESOLVED }
    end

    trait :ignored do
      status { Chronicle::ErrorGroup::IGNORED }
    end

    trait :from_controller do
      source_type { 'controller' }
    end

    trait :from_job do
      source_type { 'job' }
    end
  end
end
