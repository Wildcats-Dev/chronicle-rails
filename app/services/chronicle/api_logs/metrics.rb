module Chronicle
  module ApiLogs
    class Metrics
      include Filterable

      FILTER_DEFINITION = {
        client_version: :exact,
        backend_version: :exact,
        device_os: :exact,
        time_zone: :exact,
        start_date: :date_range,
        end_date: :date_range,
        http_method: :exact,
        api_endpoint: :exact,
      }.freeze

      def initialize(filters: {})
        @filters = filters
        start_time, end_time = normalize_date_range
        @filters[:start_date] = start_time.to_date.to_s
        @filters[:end_date] = end_time.to_date.to_s
      end

      def kpi_cards
        scope = build_query(ApiLog, filter_definition: FILTER_DEFINITION, filters: @filters, date_column: :timestamp)
        aggregates = fetch_aggregates(scope)

        {
          total_api_calls: aggregates[:total_count],
          unique_users: aggregates[:unique_users],
          unique_devices: aggregates[:unique_devices],
          average_response_time: aggregates[:avg_response_time],
          p50_response_time: aggregates[:p50_response_time],
          p95_response_time: aggregates[:p95_response_time],
          p99_response_time: aggregates[:p99_response_time],
          error_rate_percentage: calculate_error_rate(aggregates[:total_count], aggregates[:error_count]),
          requests_per_hour: calculate_requests_per_hour(aggregates[:total_count]),
        }
      end

      def distribution_metrics
        start_time, end_time = normalize_date_range
        scope = build_query(ApiLog, filter_definition: FILTER_DEFINITION, filters: @filters, date_column: :timestamp)

        {
          status_code_distribution: fetch_status_code_distribution(scope),
          traffic_over_time: fetch_traffic_over_time(scope, start_time, end_time),
          response_time_trend: fetch_response_time_trend(scope, start_time, end_time),
        }
      end

      class << self
        def kpi_cards(filters: {})
          new(filters: filters).kpi_cards
        end

        def distribution_metrics(filters: {})
          new(filters: filters).distribution_metrics
        end
      end

      private

      def fetch_aggregates(scope)
        result = scope.pick(
          Arel.sql('COUNT(*)'),
          Arel.sql('COUNT(DISTINCT user_id)'),
          Arel.sql('COUNT(DISTINCT device_id)'),
          Arel.sql('AVG(response_time_ms)'),
          Arel.sql('COUNT(CASE WHEN http_status_code BETWEEN 400 AND 599 THEN 1 END)'),
          Arel.sql('PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY response_time_ms)'),
          Arel.sql('PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)'),
          Arel.sql('PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms)')
        )

        return default_aggregates if result.nil?

        {
          total_count: result[0] || 0,
          unique_users: result[1] || 0,
          unique_devices: result[2] || 0,
          avg_response_time: result[3]&.round(2) || 0.0,
          error_count: result[4] || 0,
          p50_response_time: result[5]&.round(2) || 0.0,
          p95_response_time: result[6]&.round(2) || 0.0,
          p99_response_time: result[7]&.round(2) || 0.0,
        }
      end

      def default_aggregates
        {
          total_count: 0,
          unique_users: 0,
          unique_devices: 0,
          avg_response_time: 0.0,
          error_count: 0,
          p50_response_time: 0.0,
          p95_response_time: 0.0,
          p99_response_time: 0.0,
        }
      end

      def calculate_error_rate(total_count, error_count)
        return 0.0 if total_count == 0

        ((error_count.to_f / total_count) * 100).round(2)
      end

      def calculate_requests_per_hour(total_count)
        return 0.0 if total_count == 0

        # Use filter dates if provided
        start_date = @filters[:start_date] || @filters['start_date']
        end_date = @filters[:end_date] || @filters['end_date']

        if start_date.present? && end_date.present?
          start_time = Util.parse_date(start_date).beginning_of_day
          end_time = Util.parse_date(end_date).end_of_day

          duration_hours = ((end_time - start_time) / 3600.0)
          return 0.0 if duration_hours == 0

          (total_count / duration_hours).round(2)
        else
          # No date range provided, return 0.0
          0.0
        end
      end

      def normalize_date_range
        @normalize_date_range ||= begin
          start_date = @filters[:start_date] || @filters['start_date']
          end_date = @filters[:end_date] || @filters['end_date']

          if start_date.present? && end_date.present?
            start_time = Util.parse_date(start_date).beginning_of_day
            end_time = Util.parse_date(end_date).end_of_day
          else
            # Default to last 6 months
            end_time = Time.current
            start_time = 6.months.ago
          end

          # Ensure max range is 6 months
          start_time = end_time - 6.months if (end_time - start_time) > 6.months

          [start_time, end_time]
        end
      end

      def calculate_time_interval(start_time, end_time)
        duration_hours = ((end_time - start_time) / 3600.0)

        if duration_hours <= 24
          { interval: 1.hour, format: '%H:%M' }
        elsif duration_hours <= 720 # 30 days
          { interval: 1.day, format: '%b %d' }
        else # More than 30 days
          { interval: 1.month, format: '%b %Y' }
        end
      end

      def fetch_status_code_distribution(scope)
        results = scope
                  .group(:http_status_code)
                  .order(Arel.sql('COUNT(*) DESC'))
                  .count

        total = 0

        status_code_frequency = results.map do |status_code, count|
          total += count
          {
            status_code: status_code,
            count: count,
          }
        end

        {
          total_count: total,
          status_codes: status_code_frequency,
        }
      end

      def fetch_traffic_over_time(scope, start_time, end_time)
        interval_config = calculate_time_interval(start_time, end_time)
        interval = interval_config[:interval]
        format = interval_config[:format]

        time_buckets = generate_time_buckets(start_time, end_time, interval)

        # Fetch actual data grouped by interval
        data = fetch_grouped_data(scope, interval_config, 'COUNT(*)')

        # Fill in missing buckets with 0
        time_buckets.map do |bucket_time|
          {
            label: bucket_time.strftime(format),
            timestamp: bucket_time.to_i,
            count: data[bucket_time] || 0,
          }
        end
      end

      def fetch_response_time_trend(scope, start_time, end_time)
        interval_config = calculate_time_interval(start_time, end_time)
        interval = interval_config[:interval]
        format = interval_config[:format]

        time_buckets = generate_time_buckets(start_time, end_time, interval)

        # Fetch avg and p95 data
        avg_data = fetch_grouped_data(scope, interval_config, 'AVG(response_time_ms)')
        p95_data = fetch_grouped_data(scope, interval_config,
                                      'PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)')

        time_buckets.map do |bucket_time|
          {
            label: bucket_time.strftime(format),
            timestamp: bucket_time.to_i,
            average_response_time: (avg_data[bucket_time] || 0).round(2),
            p95_response_time: (p95_data[bucket_time] || 0).round(2),
          }
        end
      end

      def generate_time_buckets(start_time, end_time, interval)
        buckets = []

        if interval == 1.month
          # For monthly intervals, start at beginning of month
          current_time = start_time.beginning_of_month
          while current_time <= end_time
            buckets << current_time
            current_time = (current_time + 1.month).beginning_of_month
          end
        else
          # For hour/day intervals, use regular increments
          current_time = start_time
          while current_time <= end_time
            buckets << current_time
            current_time += interval
          end
        end

        buckets
      end

      def fetch_grouped_data(scope, interval_config, aggregate_function)
        interval = interval_config[:interval]

        # Validate aggregate function to prevent SQL injection
        validate_aggregate_function!(aggregate_function)

        # Determine PostgreSQL date truncation function based on interval
        trunc_func = if interval == 1.hour
                       "date_trunc('hour', timestamp)"
                     elsif interval == 1.month
                       "date_trunc('month', timestamp)"
                     else
                       "date_trunc('day', timestamp)"
                     end

        results = scope
                  .group(Arel.sql(trunc_func))
                  .pluck(Arel.sql("#{trunc_func} as time_bucket, #{aggregate_function}"))

        results.to_h { |time_str, value| [Time.zone.parse(time_str.to_s), value] }
      end

      def validate_aggregate_function!(function)
        # Whitelist of allowed aggregate functions
        allowed_functions = [
          'COUNT(*)',
          'AVG(response_time_ms)',
          'PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)',
        ]

        return if allowed_functions.include?(function)

        raise ArgumentError, "Invalid aggregate function: #{function}"
      end
    end
  end
end
