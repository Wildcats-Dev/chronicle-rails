module Chronicle
  module Filterable
    extend ActiveSupport::Concern

    def build_query(model, filter_definition: {}, filters: {}, group_by: nil, date_column: :created_at)
      scope = model.all
      params_to_hash = filters.present? ? Util.coerce_to_hash(filters).symbolize_keys : {}

      filter_definition.each do |key, filter_type|
        param_value = params_to_hash[key]
        next if param_value.blank?

        scope = apply_filter(scope, key, filter_type, param_value, date_column)
      end

      scope = scope.group(group_by) if group_by.present?

      scope
    end

    private

    def apply_filter(scope, key, filter_type, value, date_column)
      case filter_type
      when :like
        sanitized_value = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
        scope.where(scope.arel_table[key].matches(sanitized_value))
      when :date_range
        apply_date_range_filter(scope, key, value, date_column)
      when :exact
        scope.where(key => value)
      end
    end

    def apply_date_range_filter(scope, key, value, date_column)
      date = Util.parse_date(value)
      raise BadRequestError, 'Invalid Date Format' if date.nil?

      case key
      when :start_date
        apply_date_range(scope, { from: date.beginning_of_day }, date_key: date_column)
      when :end_date
        apply_date_range(scope, { to: date.end_of_day }, date_key: date_column)
      else
        scope.where(date_column => date.all_day)
      end
    end

    def apply_date_range(scope, range, date_key: :datetime)
      return scope if range.nil?

      scope = scope.where(date_key => (range[:from])..) if range[:from].present?
      scope = scope.where(date_key => ..(range[:to]))   if range[:to].present?
      scope
    end
  end
end
