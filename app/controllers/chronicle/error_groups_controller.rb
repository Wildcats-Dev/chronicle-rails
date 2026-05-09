module Chronicle
  class ErrorGroupsController < ResourceController
    before_action :authenticate_admin_user!, only: [:index, :show, :update] # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :set_error_group, only: [:update]

    FILTER_DEFINITION = {
      project: :exact,
      source_type: :exact,
      source_name: :like,
      error_message: :like,
      status: :exact,
      fingerprint: :exact,
      backend_version: :exact,
      client_version: :exact,
      start_date: :date_range,
      end_date: :date_range,
    }.freeze

    def show
      record = ErrorGroup.find_by(id: params[:id])
      raise NotFoundError, 'Error group not found' unless record

      render json: record.get_hash, status: :ok
    end

    def update
      if params[:status].present? && ErrorGroup::VALID_STATUSES.exclude?(params[:status])
        raise BadRequestError, 'Invalid status'
      end

      @error_group.update!(update_params)
      render json: @error_group.get_hash, status: :ok
    end

    private

    def model
      ErrorGroup
    end

    def filter_definition
      FILTER_DEFINITION
    end

    def date_column
      :last_seen_at
    end

    def set_error_group
      @error_group = ErrorGroup.find_by(id: params[:id])
      raise NotFoundError, 'Error group not found' unless @error_group
    end

    def update_params
      params.permit(:status, :jira_link)
    end
  end
end
