module Chronicle
  class ErrorGroup < ApplicationRecord
    has_many :error_logs, dependent: :destroy

    OPEN = 'open'.freeze
    RESOLVED = 'resolved'.freeze
    IGNORED = 'ignored'.freeze
    VALID_STATUSES = [OPEN, RESOLVED, IGNORED].freeze

    validates :project, presence: true
    validates :fingerprint, presence: true
    validates :source_type,
              :source_name,
              :error_message,   presence: true
    validates :status,          inclusion: { in: VALID_STATUSES }, presence: true
    validates :first_seen_at,
              :last_seen_at,    presence: true
    validates :occurrence_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # Derives a deterministic fingerprint from the structural identity of an error.
    # Same source location + message + cleaned backtrace always yields the same hash,
    # so two occurrences of the same bug map to the same group.
    def self.compute_fingerprint(error_log)
      payload = [
        error_log.source_type,
        error_log.source_name,
        error_log.error_message,
        error_log.cleaned_backtrace.to_s.first(2000),
      ].join("\xff")
      Digest::SHA256.hexdigest(payload)
    end

    # Atomically records a new occurrence of this error.
    # Uses a row-level lock so concurrent increments never collide.
    def record_occurrence!(backend_version: nil, client_version: nil, at: Time.current)
      with_lock do
        self.last_seen_at      = [last_seen_at, at].compact.max
        self.backend_version   = backend_version if backend_version.present?
        self.client_version    = client_version  if client_version.present?
        self.occurrence_count += 1
        save!
      end
    end

    def get_hash
      attributes.symbolize_keys.merge(error_fingerprint: fingerprint)
    end

    def as_json(_options = {})
      get_hash
    end
  end
end
