module Chronicle
  module ApiLogs
    class Updater
      def initialize(request_id, frontend_response_time_ms)
        @request_id = request_id
        @frontend_response_time_ms = frontend_response_time_ms
      end

      def call
        api_log = ApiLog.find_by(request_id: @request_id)

        raise NotFoundError, "API log not found with request_id: #{@request_id}" if api_log.nil?

        api_log.update!(frontend_response_time_ms: @frontend_response_time_ms)
        api_log
      end
    end
  end
end
