require 'rails_helper'

module Chronicle
  RSpec.describe Chronicle do
    it 'has a version number' do
      expect(Chronicle::VERSION).not_to be_nil
    end

    it 'exposes the engine' do
      expect(Chronicle::Engine).to be < Rails::Engine
      expect(Chronicle::Engine.isolated?).to be true
    end

    describe '.configure' do
      before { Chronicle.reset_configuration! }
      after  { Chronicle.reset_configuration! }

      it 'yields a Configuration with sensible defaults' do
        expect(Chronicle.config.admin_user_class).to eq('Chronicle::AdminUser')
        expect(Chronicle.config.api_log_buffer).to eq(:file)
        expect(Chronicle.config.api_log_flush_interval).to eq(30)
      end

      it 'allows callers to override settings' do
        Chronicle.configure do |c|
          c.user_class    = 'User'
          c.project_name  = 'registro'
          c.api_log_buffer = :sync
        end

        expect(Chronicle.config.user_class).to eq('User')
        expect(Chronicle.config.project_name).to eq('registro')
        expect(Chronicle.config.api_log_buffer).to eq(:sync)
      end

      it 'resolves a callable backend_version' do
        Chronicle.configure { |c| c.backend_version = -> { '1.2.3' } }
        expect(Chronicle.config.resolved_backend_version).to eq('1.2.3')
      end
    end

    describe '.buffer_api_log' do
      let(:payload) { { api_endpoint: '/api/test', http_method: 'GET' } }

      it 'delegates to ApiLogs::Buffer.append' do
        expect(Chronicle::ApiLogs::Buffer).to receive(:append).with(payload)

        described_class.buffer_api_log(payload)
      end

      context 'when disable_api_logging is true' do
        before { Chronicle.configure { |c| c.disable_api_logging = true } }
        after  { Chronicle.configure { |c| c.disable_api_logging = false } }

        it 'does nothing' do
          expect(Chronicle::ApiLogs::Buffer).not_to receive(:append)

          described_class.buffer_api_log(payload)
        end
      end
    end

    describe '.bulk_log_api' do
      let(:payloads) do
        [
          { 'api_endpoint' => '/api/users', 'http_method' => 'GET', 'http_status_code' => 200 },
          { 'api_endpoint' => '/api/orders', 'http_method' => 'POST', 'http_status_code' => 201 },
        ]
      end

      it 'inserts all payloads into the database' do
        expect { described_class.bulk_log_api(payloads) }
          .to change(Chronicle::ApiLog, :count).by(2)
      end

      it 'upserts api_routes for each unique endpoint+method pair' do
        expect { described_class.bulk_log_api(payloads) }
          .to change(Chronicle::ApiRoute, :count).by(2)
      end

      it 'accepts symbol-keyed hashes' do
        sym_payloads = [{ api_endpoint: '/api/ping', http_method: 'GET', http_status_code: 200 }]

        expect { described_class.bulk_log_api(sym_payloads) }
          .to change(Chronicle::ApiLog, :count).by(1)
      end

      it 'is a no-op when the array is empty' do
        expect { described_class.bulk_log_api([]) }
          .not_to change(Chronicle::ApiLog, :count)
      end

      it 'is a no-op when passed nil' do
        expect { described_class.bulk_log_api(nil) }
          .not_to change(Chronicle::ApiLog, :count)
      end

      context 'when disable_api_logging is true' do
        before { Chronicle.configure { |c| c.disable_api_logging = true } }
        after  { Chronicle.configure { |c| c.disable_api_logging = false } }

        it 'does not insert any records' do
          expect { described_class.bulk_log_api(payloads) }
            .not_to change(Chronicle::ApiLog, :count)
        end
      end

      it 'processes large batches in slices of INSERT_BATCH_SIZE' do
        allow(ApiLog).to receive(:insert_all).and_call_original
        stub_const('Chronicle::ApiLogs::Flusher::INSERT_BATCH_SIZE', 10)

        many = Array.new(25) do |i|
          { 'api_endpoint' => "/api/r#{i}", 'http_method' => 'GET', 'http_status_code' => 200 }
        end

        expect { described_class.bulk_log_api(many) }
          .to change(Chronicle::ApiLog, :count).by(many.size)

        expect(ApiLog).to have_received(:insert_all).thrice
      end
    end

    describe '.log_error' do
      let(:payload) do
        {
          project: 'chronicle',
          source_type: 'controller',
          source_name: 'users#index',
          error_message: 'Something went wrong',
          original_backtrace: 'app/controllers/users_controller.rb:10',
          cleaned_backtrace: 'app/controllers/users_controller.rb:10',
          backend_version: '1.0.0',
          client_version: '1.0.0',
        }
      end

      it 'creates an ErrorLog record' do
        expect { described_class.log_error(payload) }
          .to change(Chronicle::ErrorLog, :count).by(1)
      end

      it 'creates an ErrorGroup via GroupResolver' do
        expect { described_class.log_error(payload) }
          .to change(Chronicle::ErrorGroup, :count).by(1)
      end

      it 'increments occurrence_count on repeat errors with the same fingerprint' do
        described_class.log_error(payload)
        described_class.log_error(payload)

        expect(Chronicle::ErrorGroup.count).to eq(1)
        expect(Chronicle::ErrorGroup.first.occurrence_count).to eq(2)
      end

      context 'when disable_error_logging is true' do
        before { Chronicle.configure { |c| c.disable_error_logging = true } }
        after  { Chronicle.configure { |c| c.disable_error_logging = false } }

        it 'does not create any records' do
          expect { described_class.log_error(payload) }
            .not_to change(Chronicle::ErrorLog, :count)
        end
      end
    end

    describe '.flush_api_logs!' do
      it 'delegates to ApiLogs::Flusher.call' do
        expect(Chronicle::ApiLogs::Flusher).to receive(:call).and_return({ files: 0, records: 0 })

        described_class.flush_api_logs!
      end
    end
  end
end
