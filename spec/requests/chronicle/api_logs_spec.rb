require 'rails_helper'

module Chronicle
  RSpec.describe ApiLogsController, type: :request do
    let(:admin_user) { create(:admin_user, auth_token: 'test_auth_token') }
    let(:admin_headers) { headers.merge('X-Admin-Auth-Token' => admin_user.auth_token) }
    let(:admin_index_url) { '/chronicle/admin/api_logs' }
    let(:invalid_api_token) { 'invalid_api_token' }
    let(:empty_api_token) { '' }

    let(:invalid_api_token) { 'invalid_api_token' }
    let(:empty_api_token) { '' }

    describe 'GET /chronicle/admin/api_logs' do
      let!(:ios_log) do
        create(:api_log, device_os: 'iOS', http_method: 'GET', api_endpoint: '/api/users',
                         http_status_code: 200, brand: 'Apple', client_version: '2.0.0',
                         backend_version: '1.0.0', time_zone: 'UTC')
      end
      let!(:android_log) do
        create(:api_log, :android, http_method: 'POST', api_endpoint: '/api/orders',
                                   http_status_code: 201, client_version: '2.0.0',
                                   backend_version: '1.1.0', time_zone: 'Asia/Kolkata')
      end
      let!(:error_log) do
        create(:api_log, :error_response, device_os: 'iOS', http_method: 'GET',
                                          api_endpoint: '/api/products', http_status_code: 500,
                                          client_version: '1.5.0', backend_version: '1.0.0',
                                          time_zone: 'UTC')
      end

      context 'with valid admin token' do
        it 'returns all api logs' do
          get admin_index_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to be_an(Array)
          expect(json(response)['data'].length).to eq(3)
        end

        it 'returns empty array when no api logs exist' do
          ApiLog.delete_all
          get admin_index_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to eq([])
        end

        context 'with exact filters' do
          it 'filters by device_os' do
            get admin_index_url, params: { filters: { device_os: 'iOS' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |log| log['device_os'] == 'iOS' }).to be true
          end

          it 'filters by http_method' do
            get admin_index_url, params: { filters: { http_method: 'POST' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['http_method']).to eq('POST')
          end

          it 'filters by http_status_code' do
            get admin_index_url, params: { filters: { http_status_code: 500 } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['http_status_code']).to eq(500)
          end

          it 'filters by client_version' do
            get admin_index_url, params: { filters: { client_version: '2.0.0' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |log| log['client_version'] == '2.0.0' }).to be true
          end

          it 'filters by backend_version' do
            get admin_index_url, params: { filters: { backend_version: '1.0.0' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |log| log['backend_version'] == '1.0.0' }).to be true
          end

          it 'filters by brand' do
            get admin_index_url, params: { filters: { brand: 'Apple' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].all? { |log| log['brand'] == 'Apple' }).to be true
          end

          it 'filters by time_zone' do
            get admin_index_url, params: { filters: { time_zone: 'UTC' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |log| log['time_zone'] == 'UTC' }).to be true
          end
        end

        context 'with like filters' do
          it 'filters by api_endpoint with partial match' do
            get admin_index_url, params: { filters: { api_endpoint: '/api/us' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['api_endpoint']).to include('/api/us')
          end

          it 'filters by device_model_name with partial match' do
            get admin_index_url, params: { filters: { device_model_name: 'iPhone' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].all? { |log| log['device_model_name'].include?('iPhone') }).to be true
          end
        end

        context 'with combined filters' do
          it 'combines multiple exact filters' do
            get admin_index_url, params: { filters: { device_os: 'iOS', http_status_code: 200 } },
                                 headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['device_os']).to eq('iOS')
            expect(json(response)['data'][0]['http_status_code']).to eq(200)
          end

          it 'combines exact and like filters' do
            get admin_index_url, params: { filters: { device_os: 'iOS', api_endpoint: '/api/' } },
                                 headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].all? { |log| log['device_os'] == 'iOS' }).to be true
            expect(json(response)['data'].all? { |log| log['api_endpoint'].include?('/api/') }).to be true
          end
        end

        context 'with date range filters' do
          it 'filters by start_date' do
            yesterday_log = create(:api_log, timestamp: 2.days.ago)
            get admin_index_url, params: { filters: { start_date: Date.yesterday.to_s } },
                                 headers: admin_headers
            expect(response).to have_http_status(:ok)
            returned_ids = json(response)['data'].pluck('id')
            expect(returned_ids).not_to include(yesterday_log.id)
          end

          it 'filters by end_date' do
            future_log = create(:api_log, timestamp: 2.days.from_now)
            get admin_index_url, params: { filters: { end_date: Date.tomorrow.to_s } },
                                 headers: admin_headers
            expect(response).to have_http_status(:ok)
            returned_ids = json(response)['data'].pluck('id')
            expect(returned_ids).not_to include(future_log.id)
          end
        end

        context 'with pagination' do
          before { create_list(:api_log, 5) }

          it 'returns paginated results' do
            get admin_index_url, params: { limit: 3 }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(3)
            expect(json(response)['pagination']['has_more']).to eq(true)
            expect(json(response)['pagination']['batch_count']).to eq(3)
            ids = json(response)['data'].pluck('id')
            expect(ids).to eq(ids.sort.reverse)
          end

          it 'returns next page using cursor' do
            get admin_index_url, params: { limit: 5 }, headers: admin_headers
            last_id = json(response)['pagination']['last_id']

            get admin_index_url, params: { limit: 5, last_id: last_id }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['pagination']['has_more']).to eq(false)
          end
        end
      end

      context 'without admin token' do
        it 'returns forbidden when no auth token is provided' do
          get admin_index_url, headers: headers
          expect(response).to have_http_status(:forbidden)
        end

        it 'returns forbidden when an invalid auth token is provided' do
          get admin_index_url, headers: headers.merge('X-Auth-Token' => 'invalid_token')
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'GET /chronicle/admin/api_logs/:id' do
      let(:user_id) { 1 }
      let(:user_model) { class_double('User') }
      let(:user) do
        instance_double(
          'User',
          basic_info: {
            'id' => user_id,
            'name' => 'Sathwik',
            'email' => 'sathwik@example.com',
          }
        )
      end
      let!(:api_log) do
        create(:api_log, device_os: 'iOS', http_method: 'GET', api_endpoint: '/api/users',
                         http_status_code: 200, user_id: user_id)
      end

      def show_url(id = api_log.id)
        "/chronicle/admin/api_logs/#{id}"
      end

      context 'with valid admin token' do
        before do
          allow(Chronicle.config).to receive(:user_model).and_return(user_model)

          allow(user_model)
            .to receive(:find_by)
            .with(id: user_id)
            .and_return(user)
        end

        it 'returns the api log with attributes' do
          get show_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          json_response = response.parsed_body
          expect(json_response['id']).to eq(api_log.id)
          expect(json_response['device_os']).to eq('iOS')
          expect(json_response['http_method']).to eq('GET')
          expect(json_response['api_endpoint']).to eq('/api/users')
          expect(json_response['http_status_code']).to eq(200)
        end

        it 'includes user info via get_hash' do
          get show_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          json_response = response.parsed_body
          expect(json_response).to have_key('user')
          expect(json_response['user']).to include('email', 'id', 'name')
        end

        it 'does not include user when user_id is not present' do
          api_log2 = create(:api_log, device_os: 'iOS', http_method: 'GET', api_endpoint: '/api/users',
                                      http_status_code: 200)

          get show_url(api_log2.id), headers: admin_headers
          expect(response).to have_http_status(:ok)
          json_response = response.parsed_body
          expect(json_response['user']).to be_nil
        end

        it 'returns not found for non-existent api log' do
          get '/chronicle/admin/api_logs/999999', headers: admin_headers
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'without admin token' do
        it 'returns forbidden' do
          get show_url, headers: headers
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
