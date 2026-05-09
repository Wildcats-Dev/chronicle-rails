require 'fileutils'
require 'json'

module Chronicle
  module ApiLogs
    # Append-only, per-process file buffer for API log payloads.
    #
    # Each Puma/SolidQueue worker writes to its own `api_logs.{pid}.jsonl`
    # file, so no cross-process locking is needed. The Flusher reads all
    # PID files when it runs.
    class Buffer
      FILE_PREFIX = 'api_logs'.freeze
      FILE_EXT    = 'jsonl'.freeze

      class << self
        def append(payload)
          dir = buffer_dir
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          path = current_file_path
          File.open(path, 'a') { |f| f.puts(payload.to_json) }

          maybe_flush(path)
        end

        def buffer_dir
          configured = Chronicle.config.api_log_buffer_dir
          return configured if configured.present?

          if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
            Rails.root.join('tmp/chronicle').to_s
          else
            File.join(Dir.tmpdir, 'chronicle')
          end
        end

        def current_file_path
          File.join(buffer_dir, "#{FILE_PREFIX}.#{Process.pid}.#{FILE_EXT}")
        end

        def line_count(path)
          return 0 unless File.exist?(path)
          count = 0
          File.foreach(path) { count += 1 }
          count
        end

        private

        def maybe_flush(path)
          threshold = Chronicle.config.api_log_flush_size
          return if threshold.nil? || threshold <= 0
          return if line_count(path) < threshold

          Chronicle::FlushApiLogsJob.perform_later
        rescue StandardError
          # Never let a flush enqueue failure break the request path.
        end
      end
    end
  end
end
