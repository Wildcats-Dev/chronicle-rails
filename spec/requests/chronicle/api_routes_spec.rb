require 'rails_helper'

module Chronicle
  RSpec.describe ApiRoutesController, type: :request do
    let(:admin_user)    { create(:admin_user, auth_token: 'test_auth_token') }
    let(:admin_headers) { headers.merge('X-Admin-Auth-Token' => admin_user.auth_token) }
    let(:index_url)     { '/chronicle/admin/api_routes' }

    describe 'GET /chronicle/admin/api_routes' do
      let!(:get_users)    { create(:api_route, path: '/api/users',  http_method: 'GET') }
      let!(:post_users)   { create(:api_route, path: '/api/users',  http_method: 'POST') }
      let!(:get_orders)   { create(:api_route, path: '/api/orders', http_method: 'GET') }

      context 'with valid admin token' do
        it 'returns all api routes' do
          get index_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to be_an(Array)
          expect(json(response)['data'].length).to eq(3)
        end

        it 'returns pagination metadata' do
          get index_url, headers: admin_headers
          pagination = json(response)['pagination']
          expect(pagination).to include('has_more', 'last_id', 'batch_count')
        end

        it 'returns empty array when no routes exist' do
          ApiRoute.delete_all
          get index_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to eq([])
        end

        context 'with http_method filter' do
          it 'filters by http_method' do
            get index_url, params: { filters: { http_method: 'GET' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |r| r['http_method'] == 'GET' }).to be true
          end

          it 'returns no results for a non-matching http_method' do
            get index_url, params: { filters: { http_method: 'DELETE' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data']).to eq([])
          end
        end

        context 'with path filter' do
          it 'filters by http_method - full match' do
            get index_url, params: { filters: { path: '/api/users' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].pluck('http_method')).to match_array(%w[GET POST])
          end

          it 'filters by http_method - partial match' do
            get index_url, params: { filters: { path: '/users' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].pluck('http_method')).to match_array(%w[GET POST])
          end

          it 'returns no results for a non-matching http_method' do
            get index_url, params: { filters: { http_method: 'DELETE' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data']).to eq([])
          end
        end

        context 'with pagination' do
          before { create_list(:api_route, 27) }

          it 'defaults to 20 records per page' do
            get index_url, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(20)
            expect(json(response)['pagination']['has_more']).to be true
          end

          it 'supports cursor-based pagination' do
            get index_url, params: { limit: 25 }, headers: admin_headers
            last_id = json(response)['pagination']['last_id']

            get index_url, params: { limit: 25, last_id: last_id }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['pagination']['has_more']).to be false
          end

          it 'accepts a custom limit' do
            get index_url, params: { limit: 5 }, headers: admin_headers
            expect(json(response)['data'].length).to eq(5)
          end
        end
      end

      context 'without admin token' do
        it 'returns forbidden when no auth token is provided' do
          get index_url, headers: headers
          expect(response).to have_http_status(:forbidden)
        end

        it 'returns forbidden when an invalid auth token is provided' do
          get index_url, headers: headers.merge('X-Auth-Token' => 'bad_token')
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'GET /chronicle/admin/api_routes/stats' do
      let(:stats_url) { '/chronicle/admin/api_routes/stats' }
      let(:base_time) { Time.zone.local(2026, 3, 15, 12, 0, 0) }
      let(:date_filters) { { filters: { start_date: '2026-03-01', end_date: '2026-03-31' } } }

      # Suppress ApiLog after_commit hook so factories don't auto-populate api_routes
      before { allow_any_instance_of(ApiLog).to receive(:sync_api_route) }

      before do
        create(:api_log, api_endpoint: '/api/users',  http_method: 'GET',  http_status_code: 200,
                         response_time_ms: 100, timestamp: base_time)
        create(:api_log, api_endpoint: '/api/orders', http_method: 'POST', http_status_code: 500,
                         response_time_ms: 800, timestamp: base_time)
        create(:api_log, api_endpoint: '/api/orders', http_method: 'POST', http_status_code: 200,
                         response_time_ms: 600, timestamp: base_time)
      end

      context 'with valid admin token' do
        it 'returns 200 OK' do
          get stats_url, params: date_filters, headers: admin_headers
          expect(response).to have_http_status(:ok)
        end

        it 'returns data and pagination keys' do
          get stats_url, params: date_filters, headers: admin_headers
          body = json(response)
          expect(body).to include('data', 'pagination')
          expect(body['pagination']).to include('total_count', 'page', 'per_page', 'total_pages')
        end

        it 'each row includes all metric keys' do
          get stats_url, params: date_filters, headers: admin_headers
          row = json(response)['data'].first
          expect(row.keys).to include(
            'path', 'http_method',
            'total_requests', 'unique_users', 'requests_per_hour',
            'avg_response_time_ms', 'p95_response_time_ms', 'p99_response_time_ms',
            'error_rate_percentage'
          )
        end

        it 'defaults to sorting by avg_response_time_ms descending' do
          get stats_url, params: date_filters, headers: admin_headers
          avg_times = json(response)['data'].pluck('avg_response_time_ms')
          expect(avg_times).to eq(avg_times.sort.reverse)
        end

        it 'accepts sort_by and sort_direction params' do
          get stats_url, params: date_filters.merge(sort_by: 'total_requests', sort_direction: 'asc'),
                         headers: admin_headers
          counts = json(response)['data'].pluck('total_requests')
          expect(counts).to eq(counts.sort)
        end

        it 'filters by http_method' do
          get stats_url, params: { filters: date_filters[:filters].merge(http_method: 'GET') },
                         headers: admin_headers
          expect(json(response)['data'].length).to eq(1)
          expect(json(response)['data'].first['http_method']).to eq('GET')
        end

        it 'searches by partial api_endpoint path' do
          get stats_url, params: { filters: date_filters[:filters].merge(api_endpoint: '/api/us') },
                         headers: admin_headers
          expect(json(response)['data'].length).to eq(1)
          expect(json(response)['data'].first['path']).to eq('/api/users')
        end

        it 'supports page and per_page params' do
          get stats_url, params: date_filters.merge(per_page: 1, page: 1), headers: admin_headers
          body = json(response)
          expect(body['data'].length).to eq(1)
          expect(body['pagination']['total_count']).to eq(2)
          expect(body['pagination']['total_pages']).to eq(2)
        end

        it 'returns empty data when no logs exist in range' do
          get stats_url,
              params: { filters: { start_date: '2020-01-01', end_date: '2020-01-31' } },
              headers: admin_headers
          expect(json(response)['data']).to be_empty
          expect(json(response)['pagination']['total_count']).to eq(0)
        end
      end

      context 'without admin token' do
        it 'returns forbidden when no auth token is provided' do
          get stats_url, params: date_filters, headers: headers
          expect(response).to have_http_status(:forbidden)
        end

        it 'returns forbidden when an invalid auth token is provided' do
          get stats_url, params: date_filters,
                         headers: headers.merge('X-Auth-Token' => 'bad_token')
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
