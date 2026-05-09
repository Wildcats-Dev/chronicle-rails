module Chronicle
  class FlushApiLogsJob < ApplicationJob
    queue_as :low

    def perform
      Chronicle.flush_api_logs!
    end
  end
end
