module Chronicle
  module ErrorLogs
    # Resolves the ErrorGroup for a new ErrorLog.
    #
    # Responsibilities:
    #   - Derive the fingerprint (use the caller-supplied one, or compute from
    #     the log's structural identity if none was given).
    #   - Find an existing group for that fingerprint and increment its
    #     occurrence tracking.
    #   - Create a brand-new group when none exists yet.
    #   - Handle the concurrent-insert race condition transparently.
    class GroupResolver
      def initialize(error_log)
        @error_log = error_log
      end

      def call
        existing = ErrorGroup.find_by(project: error_log.project, fingerprint: fingerprint)
        return bump_occurrence(existing) if existing

        create_group
      rescue ActiveRecord::RecordNotUnique
        # A concurrent request won the INSERT race. Find the winner and record
        # this occurrence against it so the count stays accurate.
        bump_occurrence(ErrorGroup.find_by!(project: error_log.project, fingerprint: fingerprint))
      end

      private

      attr_reader :error_log

      def fingerprint
        @fingerprint ||= error_log.error_fingerprint.presence ||
                         ErrorGroup.compute_fingerprint(error_log)
      end

      def versions
        { backend_version: error_log.backend_version, client_version: error_log.client_version }
      end

      def bump_occurrence(group)
        group.record_occurrence!(**versions)
        group
      end

      def create_group
        now = Time.current
        ErrorGroup.create!(
          project: error_log.project,
          fingerprint: fingerprint,
          source_type: error_log.source_type,
          source_name: error_log.source_name,
          error_message: error_log.error_message,
          original_backtrace: error_log.original_backtrace,
          cleaned_backtrace: error_log.cleaned_backtrace,
          backend_version: error_log.backend_version,
          client_version: error_log.client_version,
          status: ErrorGroup::OPEN,
          first_seen_at: now,
          last_seen_at: now,
          occurrence_count: 1
        )
      end
    end
  end
end
