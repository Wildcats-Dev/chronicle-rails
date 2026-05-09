require 'rails_helper'

module Chronicle
  module ApiLogs
    RSpec.describe Buffer do
      let(:tmpdir) { Dir.mktmpdir('chronicle_buffer_test') }

      before { Chronicle.configure { |c| c.api_log_buffer_dir = tmpdir } }
      after  { FileUtils.rm_rf(tmpdir) }

      describe '.buffer_dir' do
        it 'returns the configured directory' do
          expect(described_class.buffer_dir).to eq(tmpdir)
        end

        context 'when no custom dir is configured' do
          before { Chronicle.configure { |c| c.api_log_buffer_dir = nil } }

          it 'defaults to Rails.root/tmp/chronicle' do
            expect(described_class.buffer_dir).to eq(Rails.root.join('tmp/chronicle').to_s)
          end
        end
      end

      describe '.current_file_path' do
        it 'returns a path inside buffer_dir named with the current PID' do
          path = described_class.current_file_path

          expect(path).to start_with(tmpdir)
          expect(File.basename(path)).to eq("api_logs.#{Process.pid}.jsonl")
        end
      end

      describe '.line_count' do
        it 'returns 0 for a non-existent file' do
          expect(described_class.line_count('/nonexistent/path/file.jsonl')).to eq(0)
        end

        it 'returns the correct number of lines for an existing file' do
          path = File.join(tmpdir, 'count_test.jsonl')
          File.write(path, "line1\nline2\nline3\n")

          expect(described_class.line_count(path)).to eq(3)
        end

        it 'returns 0 for an empty file' do
          path = File.join(tmpdir, 'empty.jsonl')
          File.write(path, '')

          expect(described_class.line_count(path)).to eq(0)
        end
      end

      describe '.append' do
        let(:payload) { { api_endpoint: '/api/users', http_method: 'GET', http_status_code: 200 } }

        it 'creates the buffer directory if it does not exist' do
          subdir = File.join(tmpdir, 'new_subdir')
          Chronicle.configure { |c| c.api_log_buffer_dir = subdir }

          expect { described_class.append(payload) }
            .to change { File.directory?(subdir) }.from(false).to(true)
        end

        it 'writes the payload as a valid JSON line to the buffer file' do
          described_class.append(payload)

          raw = File.read(described_class.current_file_path).strip
          parsed = JSON.parse(raw)

          expect(parsed['api_endpoint']).to eq('/api/users')
          expect(parsed['http_method']).to eq('GET')
          expect(parsed['http_status_code']).to eq(200)
        end

        it 'appends successive payloads as separate lines in the same file' do
          described_class.append(payload)
          described_class.append(payload.merge(http_status_code: 404))

          lines = File.readlines(described_class.current_file_path, chomp: true)
                      .map { |l| JSON.parse(l) }

          expect(lines.size).to eq(2)
          expect(lines.pluck('http_status_code')).to contain_exactly(200, 404)
        end

        it 'serialises symbol keys to string keys in JSON' do
          described_class.append({ api_endpoint: '/api/test', http_method: 'POST' })

          raw = File.read(described_class.current_file_path).strip
          parsed = JSON.parse(raw)

          expect(parsed).to have_key('api_endpoint')
          expect(parsed).to have_key('http_method')
        end

        context 'when flush threshold is exceeded' do
          before do
            Chronicle.configure do |c|
              c.api_log_buffer_dir = tmpdir
              c.api_log_flush_size = 2
            end
          end

          it 'enqueues a FlushApiLogsJob' do
            allow(Chronicle::FlushApiLogsJob).to receive(:perform_later)

            3.times { described_class.append(payload) }

            expect(Chronicle::FlushApiLogsJob).to have_received(:perform_later).at_least(:once)
          end
        end

        context 'when flush threshold is nil' do
          before do
            Chronicle.configure do |c|
              c.api_log_buffer_dir = tmpdir
              c.api_log_flush_size = nil
            end
          end

          it 'never enqueues a FlushApiLogsJob' do
            expect(Chronicle::FlushApiLogsJob).not_to receive(:perform_later)

            5.times { described_class.append(payload) }
          end
        end

        context 'when flush threshold is zero' do
          before do
            Chronicle.configure do |c|
              c.api_log_buffer_dir = tmpdir
              c.api_log_flush_size = 0
            end
          end

          it 'never enqueues a FlushApiLogsJob' do
            expect(Chronicle::FlushApiLogsJob).not_to receive(:perform_later)

            5.times { described_class.append(payload) }
          end
        end

        context 'when FlushApiLogsJob raises an error during enqueue' do
          before do
            Chronicle.configure do |c|
              c.api_log_buffer_dir = tmpdir
              c.api_log_flush_size = 1
            end
          end

          it 'swallows the error and does not raise' do
            allow(Chronicle::FlushApiLogsJob).to receive(:perform_later).and_raise(StandardError, 'queue down')

            expect { described_class.append(payload) }.not_to raise_error
          end
        end
      end
    end
  end
end
