require 'rails_helper'

module Chronicle
  RSpec.describe Chronicle::ErrorLogsController, type: :request do
    let(:admin_user) { create(:admin_user, auth_token: 'test_auth_token') }
    let(:headers)       { { 'X-API-TOKEN' => ENV['API_TOKEN'] || 'test_token' } }
    let(:admin_headers) { headers.merge('X-Admin-Auth-Token' => admin_user.auth_token) }
    let(:admin_url)     { '/chronicle/admin/error_logs' }
    let(:post_url)      { '/chronicle/error_logs' }

    # status is intentionally absent — it lives on ErrorGroup, not ErrorLog.
    let(:valid_payload) do
      {
        project: 'chronicle',
        source_type: 'controller',
        source_name: 'worker',
        context: { foo: 'bar' },
        error_message: 'Something went wrong',
        original_backtrace: 'line 1 \n line 2',
        cleaned_backtrace: 'line 1',
        request_id: 'req_123',
        error_fingerprint: 'abc123',
        backend_version: '1.0.0',
        client_version: '1.0.0',
        user_id: nil,
      }
    end

    describe 'GET /chronicle/admin/error_logs' do
      let!(:error_log1) { create(:error_log, request_id: 'req_aaa', backend_version: '1.0.0') }
      let!(:error_log2) { create(:error_log, request_id: 'req_bbb', backend_version: '2.0.0') }
      let!(:error_log3) { create(:error_log, request_id: 'req_ccc', backend_version: '1.0.0') }

      context 'with valid API token' do
        it 'returns all error logs' do
          get admin_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to be_an(Array)
          expect(json(response)['data'].length).to eq(3)
        end

        it 'returns empty array when no error logs exist' do
          ErrorLog.delete_all
          get admin_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to eq([])
        end

        context 'with filters' do
          it 'filters by request_id' do
            get admin_url, params: { filters: { request_id: 'req_aaa' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['request_id']).to eq('req_aaa')
          end

          it 'filters by backend_version' do
            get admin_url, params: { filters: { backend_version: '2.0.0' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['backend_version']).to eq('2.0.0')
          end

          it 'filters by client_version' do
            create(:error_log, client_version: '9.9.9')
            get admin_url, params: { filters: { client_version: '9.9.9' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['client_version']).to eq('9.9.9')
          end

          it 'filters by user_id' do
            create(:error_log, user_id: 999)
            get admin_url, params: { filters: { user_id: 999 } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].all? { |log| log['user_id'] == 999 }).to be true
          end

          it 'filters by error_group_id' do
            get admin_url, params: { filters: { error_group_id: error_log1.error_group_id } },
                           headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].all? do |log|
              log['error_group_id'] == error_log1.error_group_id
            end).to be true
          end
        end

        context 'with pagination' do
          before { create_list(:error_log, 5) }

          it 'returns paginated results with cursor-based pagination' do
            get admin_url, params: { limit: 3 }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            body = json(response)
            expect(body['data'].length).to eq(3)
            expect(body['pagination']['has_more']).to be true
            expect(body['pagination']['batch_count']).to eq(3)
            expect(body['data'].pluck('id')).to eq(body['data'].pluck('id').sort.reverse)
          end

          it 'returns next page using cursor' do
            get admin_url, params: { limit: 5 }, headers: admin_headers
            last_id = json(response)['pagination']['last_id']

            get admin_url, params: { limit: 5, last_id: last_id }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['pagination']['has_more']).to be false
            expect(json(response)['pagination']['batch_count']).to eq(3)
          end
        end
      end
    end

    describe 'GET /chronicle/admin/error_logs/:id' do
      let!(:error_log) { create(:error_log, :from_controller, :open, source_name: 'users#show') }
      let(:show_url)   { "/chronicle/admin/error_logs/#{error_log.id}" }

      it 'returns the error log with inlined group fields' do
        get show_url, headers: admin_headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['id']).to eq(error_log.id)
        expect(body['source_type']).to eq('controller')
        expect(body['source_name']).to eq('users#show')
        expect(body['status']).to eq('open')
        expect(body['error_group']).to be_a(Hash)
        expect(body['error_group']['occurrence_count']).to eq(1)
      end

      it 'returns not found for a non-existent error log' do
        get '/chronicle/admin/error_logs/99999', headers: admin_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'DELETE /chronicle/error_logs/:id' do
      let!(:error_log) { create(:error_log, error_fingerprint: 'abc123') }
      let(:delete_url) { "/chronicle/error_logs/#{error_log.id}" }

      it 'destroys the error log and returns no content' do
        expect do
          delete delete_url, headers: admin_headers
        end.to change(ErrorLog, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end

      context 'without admin auth' do
        it 'returns forbidden' do
          delete delete_url, headers: headers
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
