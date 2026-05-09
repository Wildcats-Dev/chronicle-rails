require 'json'

module Chronicle
  module ApiLogs
    # Reads all per-PID buffer files, bulk-inserts their contents into
    # chronicle_api_logs, upserts api_routes, and deletes the consumed files.
    #
    # Atomic-rename strategy: each buffer file is renamed to a `.flushing-*`
    # name before reading, so concurrent writers (same PID) recreate the
    # original file and never lose entries.
    class Flusher
      INSERT_BATCH_SIZE = 1000

      class << self
        def call
          paths = claim_files
          return { files: 0, records: 0 } if paths.empty?

          records = paths.flat_map { |p| read_jsonl(p) }
          return cleanup_and_return(paths, 0) if records.empty?

          insert_logs(records)
          sync_routes(records)

          cleanup_and_return(paths, records.size)
        end

        def sync_routes(records)
          now = Time.current
          pairs = records.filter_map do |r|
            path = r['api_endpoint']
            method = r['http_method']
            next if path.blank? || method.blank?
            [path, method]
          end.uniq

          return if pairs.empty?

          rows = pairs.map do |path, method|
            { path: path, http_method: method, first_seen_at: now, created_at: now, updated_at: now }
          end

          ApiRoute.insert_all(rows, unique_by: 'index_chronicle_api_routes_on_path_and_method') # rubocop:disable Rails/SkipsModelValidations
        end

        private

        def claim_files
          dir = Buffer.buffer_dir
          return [] unless File.directory?(dir)

          glob = File.join(dir, "#{Buffer::FILE_PREFIX}.*.#{Buffer::FILE_EXT}")
          stamp = Time.now.utc.strftime('%Y%m%d%H%M%S%N')

          Dir.glob(glob).reject { |p| p.include?('.flushing-') }.filter_map do |path|
            target = path.sub(/\.#{Buffer::FILE_EXT}\z/o, ".flushing-#{stamp}.#{Buffer::FILE_EXT}")
            begin
              File.rename(path, target)
              target
            rescue Errno::ENOENT
              nil
            end
          end
        end

        def read_jsonl(path)
          File.foreach(path).filter_map do |line|
            line = line.strip
            next if line.empty?
            JSON.parse(line)
          rescue JSON::ParserError
            nil
          end
        end

        def insert_logs(records)
          now = Time.current
          allowed = ApiLog.column_names - ['id']

          records.each_slice(INSERT_BATCH_SIZE) do |batch|
            rows = batch.map do |raw|
              row = raw.slice(*allowed)
              row['created_at'] ||= now
              row['updated_at'] ||= now
              row
            end
            ApiLog.insert_all(rows) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        def cleanup_and_return(paths, count)
          paths.each { |p| FileUtils.rm_f(p) }
          { files: paths.size, records: count }
        end
      end
    end
  end
end
