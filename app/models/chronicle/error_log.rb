module Chronicle
  class ErrorLog < ApplicationRecord
    belongs_to :error_group

    # Constants are re-exported so callers can reference ErrorLog::OPEN etc.
    # without knowing about the group model.
    OPEN          = ErrorGroup::OPEN
    RESOLVED      = ErrorGroup::RESOLVED
    IGNORED       = ErrorGroup::IGNORED
    VALID_STATUSES = ErrorGroup::VALID_STATUSES

    # These fields do not live in error_logs; they are provided at creation time
    # and forwarded to the ErrorGroup by GroupResolver.  After the group is
    # resolved the reader methods below return the persisted group values.
    attr_writer :project, :source_type, :source_name, :error_message,
                :error_fingerprint, :original_backtrace, :cleaned_backtrace

    validates :error_group, presence: true
    validates :source_type,
              :source_name,
              :error_message, presence: true, on: :create

    before_validation :resolve_error_group, on: :create

    delegate :status, :jira_link, to: :error_group, allow_nil: true

    # Reader methods: prefer the persisted group value once the log is saved;
    # fall back to the in-memory virtual attribute during the create flow.
    def project           = error_group&.project           || @project
    def source_type       = error_group&.source_type       || @source_type
    def source_name       = error_group&.source_name       || @source_name
    def error_message     = error_group&.error_message     || @error_message
    def error_fingerprint = error_group&.fingerprint       || @error_fingerprint
    def original_backtrace = error_group&.original_backtrace || @original_backtrace
    def cleaned_backtrace  = error_group&.cleaned_backtrace  || @cleaned_backtrace

    # Returns a flat hash that combines the log's own columns with the key
    # group-level fields inlined for API convenience, plus the full nested
    # group for clients that need it.
    def get_hash
      group = error_group
      attributes.symbolize_keys.merge(
        error_fingerprint: group&.fingerprint,
        project: group&.project,
        source_type: group&.source_type,
        source_name: group&.source_name,
        error_message: group&.error_message,
        original_backtrace: group&.original_backtrace,
        cleaned_backtrace: group&.cleaned_backtrace,
        status: group&.status,
        jira_link: group&.jira_link,
        error_group: group&.get_hash,
        user: (Chronicle.config.user_model&.find_by(id: user_id)&.try(:basic_info) if user_id.present?)
      )
    end

    def as_json(_options = {})
      get_hash
    end

    private

    def resolve_error_group
      return if error_group_id.present? || error_group&.persisted?

      self.error_group = ErrorLogs::GroupResolver.new(self).call
    end
  end
end
