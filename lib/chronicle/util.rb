module Chronicle
  module Util
    class << self
      def coerce_to_hash(input)
        case input
        when Hash
          input
        when ActionController::Parameters
          input.to_unsafe_h
        else
          raise ArgumentError, 'Input expected to be a hash'
        end
      end

      def parse_date(str)
        return nil if str.blank?

        begin
          Date.parse(str)
        rescue StandardError
          nil
        end
      end
    end
  end
end
