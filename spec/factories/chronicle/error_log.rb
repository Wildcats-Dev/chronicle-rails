FactoryBot.define do
  factory :error_log, class: 'Chronicle::ErrorLog' do
    # Group-level attributes passed as transient values so that callers can
    # write create(:error_log, :from_controller, source_name: 'foo') without
    # knowing about the associated ErrorGroup.  They are forwarded to the
    # group in the before(:create) hook below.
    transient do
      project          { 'chronicle' }
      source_type      { 'controller' }
      source_name      { 'users#index' }
      error_message    { 'Undefined method uuid for nil' }
      error_fingerprint { nil }
      status { Chronicle::ErrorGroup::OPEN }
    end

    request_id      { 'req_abc123' }
    backend_version { '1.0.0' }
    client_version  { '1.0.0' }
    user_id         { nil }
    context         { {} }

    before(:create) do |log, evaluator|
      if log.error_group&.persisted?
        # An explicit, already-saved group was passed — use it as-is.
      elsif log.error_group.present?
        # An unsaved group was passed — persist it first.
        log.error_group.save!
        log.error_group_id = log.error_group.id
      else
        # No group supplied — build one from the transient attributes.
        fp = evaluator.error_fingerprint || "fp-#{SecureRandom.hex(8)}"
        log.error_group = FactoryBot.create(:error_group,
                                            project: evaluator.project,
                                            source_type: evaluator.source_type,
                                            source_name: evaluator.source_name,
                                            error_message: evaluator.error_message,
                                            fingerprint: fp,
                                            status: evaluator.status)
        log.error_group_id = log.error_group.id
      end
    end

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
