module Chronicle
  class ErrorLogsController < ResourceController
    before_action :authenticate_admin_user!, only: [:index, :show, :destroy] # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :set_error_log, only: [:destroy]

    FILTER_DEFINITION = {
      request_id: :exact,
      backend_version: :exact,
      client_version: :exact,
      user_id: :exact,
      error_group_id: :exact,
      start_date: :date_range,
      end_date: :date_range,
    }.freeze

    def show
      record = ErrorLog.find_by(id: params[:id])
      raise NotFoundError, 'Error log not found' unless record

      render json: record.get_hash, status: :ok
    end

    def destroy
      @error_log.destroy
      render status: :no_content
    end

    private

    def model
      ErrorLog
    end

    def filter_definition
      FILTER_DEFINITION
    end

    def set_error_log
      @error_log = ErrorLog.find_by(id: params[:id])
      raise NotFoundError, 'Error log not found' unless @error_log
    end

    def eager_load_associations
      [:error_group]
    end
  end
end
