module Chronicle
  class ApiRoutesController < ResourceController
    FILTER_DEFINITION = {
      http_method: :exact,
      path: :like,
    }.freeze

    before_action :authenticate_admin_user!

    def stats
      result = ApiRoutes::Stats.new(
        filters: stats_filters,
        sort_by: params[:sort_by],
        sort_direction: params[:sort_direction],
        page: params[:page],
        per_page: params[:per_page]
      ).call
      render json: result, status: :ok
    end

    private

    def model
      ApiRoute
    end

    def filter_definition
      FILTER_DEFINITION
    end

    def stats_filters
      params.fetch(:filters, {}).permit(:start_date, :end_date, :http_method, :api_endpoint)
    end
  end
end
