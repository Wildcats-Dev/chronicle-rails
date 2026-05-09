module Chronicle
  class ApiLogsController < ResourceController
    FILTER_DEFINITION = {
      user_id: :exact,
      request_id: :exact,
      device_os: :exact,
      device_id: :exact,
      device_type: :exact,
      ip_address: :exact,
      http_method: :exact,
      api_endpoint: :like,
      http_status_code: :exact,
      brand: :exact,
      device_model_name: :like,
      os_version: :exact,
      backend_version: :exact,
      client_version: :exact,
      time_zone: :exact,
      start_date: :date_range,
      end_date: :date_range,
    }.freeze

    def update
      api_log = ApiLogs::Updater.new(params[:request_id], params.require(:frontend_response_time_ms)).call
      render json: { status: 'success', id: api_log.id }, status: :ok
    end

    def kpi_cards
      render json: ApiLogs::Metrics.kpi_cards(filters: metrics_filters), status: :ok
    end

    def distribution_metrics
      render json: ApiLogs::Metrics.distribution_metrics(filters: metrics_filters), status: :ok
    end

    private

    def model
      ApiLog
    end

    def filter_definition
      FILTER_DEFINITION
    end

    def date_column
      :timestamp
    end

    def eager_load_associations
      []
    end

    def metrics_filters
      params.fetch(:filters, {}).permit(
        :start_date, :end_date, :client_version, :backend_version,
        :device_os, :time_zone, :api_endpoint, :http_method
      )
    end
  end
end
