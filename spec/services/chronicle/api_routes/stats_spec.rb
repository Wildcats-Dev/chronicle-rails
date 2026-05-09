require 'rails_helper'

module Chronicle
  RSpec.describe ApiRoutes::Stats do
    # Suppress the after_commit hook so factory-created logs don't pollute api_routes
    before { allow_any_instance_of(ApiLog).to receive(:sync_api_route) }

    let(:base_time) { Time.zone.local(2026, 3, 1, 12, 0, 0) }
    let(:filters)   { { start_date: '2026-03-01', end_date: '2026-03-31' } }

    def call(extra_filters: {}, **)
      described_class.new(filters: filters.merge(extra_filters), **).call
    end

    def make_log(endpoint:, method:, status: 200, response_time: 100, at: base_time)
      create(:api_log, api_endpoint: endpoint, http_method: method,
                       http_status_code: status, response_time_ms: response_time,
                       timestamp: at)
    end

    describe '#call — response shape' do
      before { make_log(endpoint: '/api/users', method: 'GET') }

      it 'returns data and pagination keys' do
        result = call
        expect(result).to include(:data, :pagination)
      end

      it 'each data row has all expected metric keys' do
        row = call[:data].first
        expect(row).to include(
          :path, :http_method,
          :total_requests, :unique_users, :requests_per_hour,
          :avg_response_time_ms, :p95_response_time_ms, :p99_response_time_ms,
          :error_rate_percentage
        )
      end

      it 'pagination has all expected keys' do
        expect(call[:pagination]).to include(:total_count, :page, :per_page, :total_pages)
      end
    end

    describe '#call — aggregation correctness' do
      before do
        # /api/orders POST — 3 requests, one error
        make_log(endpoint: '/api/orders', method: 'POST', status: 200, response_time: 100)
        make_log(endpoint: '/api/orders', method: 'POST', status: 200, response_time: 200)
        make_log(endpoint: '/api/orders', method: 'POST', status: 500, response_time: 300)

        # /api/users GET — 2 requests, no errors
        make_log(endpoint: '/api/users',  method: 'GET',  status: 200, response_time: 50)
        make_log(endpoint: '/api/users',  method: 'GET',  status: 200, response_time: 150)
      end

      let(:orders_row) { call[:data].find { |r| r[:path] == '/api/orders' && r[:http_method] == 'POST' } }
      let(:users_row)  { call[:data].find { |r| r[:path] == '/api/users'  && r[:http_method] == 'GET' } }

      it 'counts total_requests per endpoint' do
        expect(orders_row[:total_requests]).to eq(3)
        expect(users_row[:total_requests]).to eq(2)
      end

      it 'calculates correct average response time' do
        expect(orders_row[:avg_response_time_ms]).to eq(200.0)  # (100+200+300)/3
        expect(users_row[:avg_response_time_ms]).to eq(100.0)   # (50+150)/2
      end

      it 'calculates error_rate_percentage correctly' do
        expect(orders_row[:error_rate_percentage]).to eq(33.33)  # 1/3
        expect(users_row[:error_rate_percentage]).to eq(0.0)
      end

      it 'returns requests_per_hour as a non-negative number' do
        expect(orders_row[:requests_per_hour]).to be >= 0
        expect(users_row[:requests_per_hour]).to be >= 0
      end

      it 'returns p95 and p99 as numbers' do
        expect(orders_row[:p95_response_time_ms]).to be_a(Numeric)
        expect(orders_row[:p99_response_time_ms]).to be_a(Numeric)
      end

      it 'returns correct total_count in pagination' do
        expect(call[:pagination][:total_count]).to eq(2)  # 2 distinct endpoint pairs
      end
    end

    describe '#call — unique_users' do
      let!(:user) { User.create!(email: 'stats_user@example.com', name: 'Stats User') }

      before do
        create(:api_log, api_endpoint: '/api/users', http_method: 'GET',
                         user_id: user.id, timestamp: base_time)
        create(:api_log, api_endpoint: '/api/users', http_method: 'GET',
                         user_id: user.id, timestamp: base_time + 1.minute)
        create(:api_log, api_endpoint: '/api/users', http_method: 'GET',
                         user_id: nil, timestamp: base_time + 2.minutes)
      end

      it 'counts distinct non-nil user_ids' do
        row = call[:data].first
        expect(row[:unique_users]).to eq(1)
      end
    end

    describe '#call — date range filter' do
      before do
        make_log(endpoint: '/api/users', method: 'GET', at: base_time)
        make_log(endpoint: '/api/users', method: 'GET', at: base_time - 2.months)
      end

      it 'only includes logs within the date range' do
        result = described_class.new(
          filters: { start_date: '2026-03-01', end_date: '2026-03-31' }
        ).call
        expect(result[:data].first[:total_requests]).to eq(1)
      end

      it 'includes all logs when range is wide' do
        result = described_class.new(
          filters: { start_date: '2026-01-01', end_date: '2026-03-31' }
        ).call
        expect(result[:data].first[:total_requests]).to eq(2)
      end
    end

    describe '#call — requests_per_hour' do
      before do
        make_log(endpoint: '/api/users', method: 'GET')
        make_log(endpoint: '/api/users', method: 'GET')
      end

      it 'equals total_requests divided by the duration in hours' do
        start_time = Time.zone.parse('2026-03-01').beginning_of_day
        end_time   = Time.zone.parse('2026-03-01').end_of_day
        duration_hours = (end_time - start_time) / 3600.0

        result = described_class.new(
          filters: { start_date: '2026-03-01', end_date: '2026-03-01' }
        ).call

        expected = (2 / duration_hours).round(2)
        expect(result[:data].first[:requests_per_hour]).to eq(expected)
      end
    end

    describe '#call — http_method filter' do
      before do
        make_log(endpoint: '/api/users', method: 'GET')
        make_log(endpoint: '/api/users', method: 'POST')
        make_log(endpoint: '/api/users', method: 'DELETE')
      end

      it 'returns only routes matching the given http_method' do
        result = call(extra_filters: { http_method: 'GET' })
        expect(result[:data].length).to eq(1)
        expect(result[:data].first[:http_method]).to eq('GET')
      end

      it 'returns all routes when no http_method filter is given' do
        expect(call[:data].length).to eq(3)
      end
    end

    describe '#call — api_endpoint search filter' do
      before do
        make_log(endpoint: '/api/users',    method: 'GET')
        make_log(endpoint: '/api/orders',   method: 'GET')
        make_log(endpoint: '/api/products', method: 'GET')
      end

      it 'does a partial match on the endpoint path' do
        result = call(extra_filters: { api_endpoint: '/api/us' })
        expect(result[:data].length).to eq(1)
        expect(result[:data].first[:path]).to eq('/api/users')
      end

      it 'returns multiple results when the pattern matches several paths' do
        result = call(extra_filters: { api_endpoint: '/api/' })
        expect(result[:data].length).to eq(3)
      end
    end

    describe '#call — sorting' do
      before do
        make_log(endpoint: '/api/slow',   method: 'GET', response_time: 900, status: 200)
        make_log(endpoint: '/api/slow',   method: 'GET', response_time: 800, status: 500)
        make_log(endpoint: '/api/medium', method: 'GET', response_time: 400, status: 200)
        make_log(endpoint: '/api/fast',   method: 'GET', response_time: 100, status: 200)
      end

      it 'defaults to avg_response_time_ms descending (slowest first)' do
        paths = call[:data].pluck(:path)
        expect(paths.first).to eq('/api/slow')
        expect(paths.last).to eq('/api/fast')
      end

      it 'sorts by avg_response_time_ms ascending when direction is asc' do
        result = call(sort_by: 'avg_response_time_ms', sort_direction: 'asc')
        expect(result[:data].first[:path]).to eq('/api/fast')
      end

      it 'sorts by total_requests descending' do
        make_log(endpoint: '/api/fast', method: 'GET', response_time: 100)
        make_log(endpoint: '/api/fast', method: 'GET', response_time: 100)
        result = call(sort_by: 'total_requests', sort_direction: 'desc')
        expect(result[:data].first[:path]).to eq('/api/fast')
      end

      it 'sorts by error_rate_percentage descending' do
        result = call(sort_by: 'error_rate_percentage', sort_direction: 'desc')
        expect(result[:data].first[:path]).to eq('/api/slow')  # 1/2 = 50% error rate
      end

      it 'sorts by requests_per_hour (proxied via total_requests)' do
        make_log(endpoint: '/api/fast', method: 'GET', response_time: 100)
        result = call(sort_by: 'requests_per_hour', sort_direction: 'desc')
        expect(result[:data].first[:path]).to eq('/api/fast')
      end

      it 'falls back to default sort for an unknown sort_by value' do
        result = call(sort_by: 'invalid_column', sort_direction: 'desc')
        expect(result[:data].first[:path]).to eq('/api/slow')
      end

      it 'falls back to desc for an unknown sort_direction' do
        result = call(sort_by: 'avg_response_time_ms', sort_direction: 'sideways')
        expect(result[:data].first[:path]).to eq('/api/slow')
      end
    end

    describe '#call — pagination' do
      before do
        10.times { |i| make_log(endpoint: "/api/resource_#{i}", method: 'GET', response_time: (i * 10) + 10) }
      end

      it 'respects the per_page limit' do
        result = call(per_page: 3)
        expect(result[:data].length).to eq(3)
      end

      it 'calculates total_pages correctly' do
        result = call(per_page: 3)
        expect(result[:pagination][:total_pages]).to eq(4)  # ceil(10/3)
      end

      it 'returns the correct page of results' do
        page1_paths = call(per_page: 4, page: 1)[:data].pluck(:path)
        page2_paths = call(per_page: 4, page: 2)[:data].pluck(:path)
        expect(page1_paths & page2_paths).to be_empty
      end

      it 'returns an empty data array for a page beyond the last' do
        result = call(per_page: 10, page: 99)
        expect(result[:data]).to be_empty
      end

      it 'caps per_page at MAX_PER_PAGE' do
        result = call(per_page: 9999)
        expect(result[:pagination][:per_page]).to eq(described_class::MAX_PER_PAGE)
      end

      it 'enforces a minimum page of 1' do
        result = call(page: -5)
        expect(result[:pagination][:page]).to eq(1)
      end
    end

    describe '#call — logs outside date range are excluded' do
      before do
        make_log(endpoint: '/api/users', method: 'GET', at: base_time)
        make_log(endpoint: '/api/users', method: 'GET', at: base_time + 2.months)
      end

      it 'excludes logs outside the given range' do
        result = described_class.new(
          filters: { start_date: '2026-03-01', end_date: '2026-03-31' }
        ).call
        expect(result[:data].first[:total_requests]).to eq(1)
      end
    end

    describe '#call — no data' do
      it 'returns empty data and zero pagination when no logs exist' do
        result = call
        expect(result[:data]).to be_empty
        expect(result[:pagination][:total_count]).to eq(0)
        expect(result[:pagination][:total_pages]).to eq(0)
      end
    end
  end
end
