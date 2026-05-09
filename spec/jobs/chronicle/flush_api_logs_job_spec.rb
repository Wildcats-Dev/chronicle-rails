require 'rails_helper'

module Chronicle
  RSpec.describe FlushApiLogsJob, type: :job do
    describe '#perform' do
      it 'delegates to Chronicle.flush_api_logs!' do
        expect(Chronicle).to receive(:flush_api_logs!)

        described_class.new.perform
      end

      it 'is queued on the :low queue' do
        expect(described_class.queue_name).to eq('low')
      end
    end
  end
end
