require 'chronicle/version'
require 'chronicle/configuration'
require 'chronicle/util'
require 'chronicle/engine'

module Chronicle
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def config
      configuration
    end

    # Buffers an API log payload to a per-process file. The buffer is
    # drained periodically by Chronicle::FlushApiLogsJob, and opportunistically
    # when the configured flush size is exceeded.
    def buffer_api_log(payload)
      return if configuration.api_logging_disabled?
      ApiLogs::Buffer.append(payload)
    end

    # Bulk-inserts API log payloads directly, bypassing the file buffer.
    # Intended for tests, backfills, or hosts that implement their own buffering.
    def bulk_log_api(payloads)
      return if configuration.api_logging_disabled?
      return if payloads.blank?

      now = Time.current
      allowed = ApiLog.column_names - ['id']
      rows = payloads.map do |raw|
        row = raw.respond_to?(:stringify_keys) ? raw.stringify_keys.slice(*allowed) : raw.slice(*allowed)
        row['created_at'] ||= now
        row['updated_at'] ||= now
        row
      end

      rows.each_slice(ApiLogs::Flusher::INSERT_BATCH_SIZE) do |batch|
        ApiLog.insert_all(batch) # rubocop:disable Rails/SkipsModelValidations
      end

      ApiLogs::Flusher.sync_routes(rows)
    end

    # Synchronously creates an ErrorLog. The model's before_validation hook
    # routes it through ErrorLogs::GroupResolver for fingerprint dedup.
    def log_error(payload)
      return if configuration.error_logging_disabled?
      ErrorLog.create!(payload)
    end

    # Drains all per-PID buffer files into the database. Safe to run
    # concurrently — atomic file renames prevent double-processing.
    def flush_api_logs!
      ApiLogs::Flusher.call
    end
  end
end
