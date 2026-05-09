module Chronicle
  module ApiRoutes
    class Stats
      SORTABLE_COLUMNS = %w[
        avg_response_time_ms
        p95_response_time_ms
        p99_response_time_ms
        error_rate_percentage
        total_requests
        unique_users
        requests_per_hour
      ].freeze

      DEFAULT_SORT_BY        = 'avg_response_time_ms'.freeze
      DEFAULT_SORT_DIRECTION = 'desc'.freeze
      DEFAULT_PER_PAGE       = 25
      MAX_PER_PAGE           = 100

      # Aliases that PostgreSQL exposes after the GROUP BY+SELECT; safe to interpolate
      # because they are taken from the SORTABLE_COLUMNS whitelist above.
      SORT_COLUMN_ALIAS = {
        'avg_response_time_ms' => 'avg_response_time_ms',
        'p95_response_time_ms' => 'p95_response_time_ms',
        'p99_response_time_ms' => 'p99_response_time_ms',
        'error_rate_percentage' => 'error_rate_percentage',
        'total_requests' => 'total_requests',
        'unique_users' => 'unique_users',
        # duration is constant per request so ordering by total_requests is equivalent
        'requests_per_hour' => 'total_requests',
      }.freeze

      AGGREGATE_SELECT = [
        'api_endpoint AS path',
        'http_method',
        'COUNT(*) AS total_requests',
        'COUNT(DISTINCT user_id) AS unique_users',
        'ROUND(AVG(response_time_ms)::numeric, 2) AS avg_response_time_ms',
        'ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 2) AS p95_response_time_ms',
        'ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms)::numeric, 2) AS p99_response_time_ms',
        'ROUND(100.0 * COUNT(CASE WHEN http_status_code BETWEEN 400 AND 599 THEN 1 END) / COUNT(*), 2)
 AS error_rate_percentage',
      ].freeze

      def initialize(filters: {}, sort_by: nil, sort_direction: nil, page: 1, per_page: DEFAULT_PER_PAGE)
        filters         = filters.to_unsafe_h.symbolize_keys if filters.respond_to?(:to_unsafe_h)
        @filters        = filters.symbolize_keys
        @sort_by        = SORTABLE_COLUMNS.include?(sort_by.to_s) ? sort_by.to_s : DEFAULT_SORT_BY
        @sort_direction = if %w[asc
                                desc].include?(sort_direction.to_s.downcase)
                            sort_direction.to_s.downcase
                          else
                            DEFAULT_SORT_DIRECTION
                          end
        @page           = [page.to_i, 1].max
        @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
        @start_time, @end_time = normalize_date_range
      end

      def call
        base    = filtered_scope
        total   = base.group(:api_endpoint, :http_method).count.size
        records = stats_scope(base)
                  .order(Arel.sql("#{SORT_COLUMN_ALIAS[@sort_by]} #{@sort_direction.upcase} NULLS LAST"))
                  .limit(@per_page)
                  .offset((@page - 1) * @per_page)

        duration_hours = [(@end_time - @start_time) / 3600.0, 1].max

        {
          data: records.map { |row| serialize(row, duration_hours) },
          pagination: {
            total_count: total,
            page: @page,
            per_page: @per_page,
            total_pages: (total.to_f / @per_page).ceil,
          },
        }
      end

      private

      def filtered_scope
        scope = ApiLog.where(timestamp: @start_time..@end_time)

        scope = scope.where(http_method: @filters[:http_method]) if @filters[:http_method].present?

        if @filters[:api_endpoint].present?
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:api_endpoint])}%"
          scope = scope.where(ApiLog.arel_table[:api_endpoint].matches(pattern))
        end

        scope
      end

      def stats_scope(base)
        base.group(:api_endpoint, :http_method).select(*AGGREGATE_SELECT)
      end

      def serialize(row, duration_hours)
        {
          path: row.path,
          http_method: row.http_method,
          total_requests: row.total_requests.to_i,
          unique_users: row.unique_users.to_i,
          requests_per_hour: (row.total_requests.to_f / duration_hours).round(2),
          avg_response_time_ms: row.avg_response_time_ms.to_f,
          p95_response_time_ms: row.p95_response_time_ms.to_f,
          p99_response_time_ms: row.p99_response_time_ms.to_f,
          error_rate_percentage: row.error_rate_percentage.to_f,
        }
      end

      def normalize_date_range
        start_date = @filters[:start_date]
        end_date   = @filters[:end_date]

        if start_date.present? && end_date.present?
          start_time = Util.parse_date(start_date).beginning_of_day
          end_time   = Util.parse_date(end_date).end_of_day
        else
          end_time   = Time.current
          start_time = 6.months.ago
        end

        start_time = end_time - 6.months if (end_time - start_time) > 6.months

        [start_time, end_time]
      end
    end
  end
end
