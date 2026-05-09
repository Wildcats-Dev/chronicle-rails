module Chronicle
  class ResourceController < ApplicationController
    include Pagination
    include Filterable

    before_action :authenticate_admin_user!, only: [:index, :show]

    def index
      query = build_query(model, filter_definition: filter_definition, filters: params[:filters],
                                 date_column: date_column)
      query = query.includes(eager_load_associations) if eager_load_associations.any?
      render json: paginate(query), status: :ok
    end

    def show
      record = model.find_by(id: params[:id])
      raise NotFoundError, 'Record not found' unless record

      data = record.respond_to?(:get_hash) ? record.get_hash : record.attributes
      render json: data, status: :ok
    end

    private

    def model
      raise NotImplementedError, "#{self.class} must define #model"
    end

    def filter_definition
      raise NotImplementedError, "#{self.class} must define #filter_definition"
    end

    def date_column
      :created_at
    end

    def eager_load_associations
      []
    end
  end
end
