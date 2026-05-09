module Chronicle
  module Pagination
    extend ActiveSupport::Concern

    DEFAULT_LIMIT = 20
    MAX_LIMIT = 100

    def paginate(scope)
      limit = validate_limit
      last_id = params[:last_id]&.to_i

      scope = scope.where(id: ...last_id) if last_id.present?
      scope = scope.order(id: order_key).limit(limit)
      batch_count = scope.size

      {
        data: scope.map { |record| item_data(record) },
        pagination: {
          has_more: batch_count == limit,
          last_id: scope.last&.id,
          batch_count: batch_count,
        },
      }
    end

    private

    def validate_limit
      limit = params[:limit].present? ? [params[:limit].to_i, 1].max : DEFAULT_LIMIT
      [limit, MAX_LIMIT].min
    end

    def order_key
      params[:order_by] == 'asc' ? :asc : :desc
    end

    def item_data(record)
      record.respond_to?(:get_hash) ? record.get_hash : record.attributes
    end
  end
end
