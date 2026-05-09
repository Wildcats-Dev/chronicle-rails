require 'rails_helper'

module Chronicle
  module ApiLogs
    RSpec.describe Flusher do
      let(:tmpdir) { Dir.mktmpdir('chronicle_flusher_test') }

      before { Chronicle.configure { |c| c.api_log_buffer_dir = tmpdir } }
      after  { FileUtils.rm_rf(tmpdir) }

      # Writes payloads as JSONL to a buffer file and returns the path.
      def write_buffer_file(payloads, pid: 99_999)
        path = File.join(tmpdir, "api_logs.#{pid}.jsonl")
        File.open(path, 'w') { |f| payloads.each { |p| f.puts(p.to_json) } }
        path
      end

      let(:base_payload) do
        {
          'api_endpoint' => '/api/users',
          'http_method' => 'GET',
          'http_status_code' => 200,
          'response_time_ms' => 120,
          'request_id' => SecureRandom.uuid,
        }
      end

      describe '.call' do
        context 'when there are no buffer files' do
          it 'returns zeros and performs no DB writes' do
            result = described_class.call

            expect(result).to eq({ files: 0, records: 0 })
            expect(ApiLog.count).to eq(0)
          end
        end

        context 'when buffer files exist with valid records' do
          before { write_buffer_file([base_payload, base_payload.merge('http_status_code' => 404)]) }

          it 'returns the correct file and record counts' do
            result = described_class.call

            expect(result[:files]).to eq(1)
            expect(result[:records]).to eq(2)
          end

          it 'inserts all records into chronicle_api_logs' do
            expect { described_class.call }.to change(ApiLog, :count).by(2)
          end

          it 'deletes the buffer file after processing' do
            described_class.call

            remaining = Dir.glob(File.join(tmpdir, '**', '*.jsonl'))
            expect(remaining).to be_empty
          end

          it 'upserts the api_route for each unique endpoint+method pair' do
            expect { described_class.call }.to change(ApiRoute, :count).by(1)

            route = ApiRoute.last
            expect(route.path).to eq('/api/users')
            expect(route.http_method).to eq('GET')
          end
        end

        context 'when buffer files exist but all lines are empty' do
          before do
            path = File.join(tmpdir, 'api_logs.11111.jsonl')
            File.write(path, "\n\n\n")
          end

          it 'returns zero records and cleans up the file' do
            result = described_class.call

            expect(result[:records]).to eq(0)
            expect(Dir.glob(File.join(tmpdir, '**', '*.jsonl'))).to be_empty
          end
        end

        context 'when a buffer file contains malformed JSON lines' do
          before do
            path = File.join(tmpdir, 'api_logs.22222.jsonl')
            File.open(path, 'w') do |f|
              f.puts(base_payload.to_json)
              f.puts('not valid json {{{{')
              f.puts(base_payload.merge('http_status_code' => 201).to_json)
            end
          end

          it 'skips corrupted lines and inserts the valid ones' do
            expect { described_class.call }.to change(ApiLog, :count).by(2)
          end
        end

        context 'when multiple buffer files exist' do
          before do
            write_buffer_file([base_payload], pid: 10_001)
            write_buffer_file([base_payload.merge('request_id' => SecureRandom.uuid)], pid: 10_002)
          end

          it 'processes all files and returns the combined count' do
            result = described_class.call

            expect(result[:files]).to eq(2)
            expect(result[:records]).to eq(2)
          end
        end

        context 'when a .flushing- file is left over from a previous crash' do
          before do
            # Simulate a stale flushing file — .call should ignore it.
            stale = File.join(tmpdir, 'api_logs.33333.flushing-20260101000000.jsonl')
            File.write(stale, "#{base_payload.to_json}\n")
          end

          it 'ignores the stale flushing file and returns no records' do
            result = described_class.call

            expect(result[:files]).to eq(0)
            expect(result[:records]).to eq(0)
          end
        end
      end

      describe '.sync_routes' do
        let(:records) do
          [
            { 'api_endpoint' => '/api/orders', 'http_method' => 'POST' },
            { 'api_endpoint' => '/api/users',  'http_method' => 'GET' },
            { 'api_endpoint' => '/api/orders', 'http_method' => 'POST' }, # duplicate
          ]
        end

        it 'inserts one route per unique path+method pair' do
          expect { described_class.sync_routes(records) }.to change(ApiRoute, :count).by(2)
        end

        it 'sets first_seen_at on new routes' do
          described_class.sync_routes(records)

          expect(ApiRoute.all).to all(have_attributes(first_seen_at: be_present))
        end

        it 'does not raise when a route already exists (ON CONFLICT DO NOTHING)' do
          create(:api_route, path: '/api/orders', http_method: 'POST')

          expect { described_class.sync_routes(records) }.not_to raise_error
          expect(ApiRoute.count).to eq(2) # only the new one gets inserted
        end

        it 'preserves first_seen_at for existing routes' do
          original_time = 1.day.ago
          create(:api_route, path: '/api/orders', http_method: 'POST', first_seen_at: original_time)

          described_class.sync_routes(records)

          route = ApiRoute.find_by(path: '/api/orders', http_method: 'POST')
          expect(route.first_seen_at).to be_within(1.second).of(original_time)
        end

        it 'skips records where api_endpoint or http_method is blank' do
          bad_records = [
            { 'api_endpoint' => '', 'http_method' => 'GET' },
            { 'api_endpoint' => '/api/test', 'http_method' => nil },
            { 'api_endpoint' => '/api/valid', 'http_method' => 'DELETE' },
          ]

          expect { described_class.sync_routes(bad_records) }.to change(ApiRoute, :count).by(1)
        end

        it 'returns early without hitting the DB when pairs is empty' do
          blank_records = [{ 'api_endpoint' => nil, 'http_method' => nil }]

          expect(ApiRoute).not_to receive(:insert_all)
          described_class.sync_routes(blank_records)
        end
      end
    end
  end
end
