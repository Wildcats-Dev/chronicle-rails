require 'rails_helper'
include ActiveSupport::Testing::TimeHelpers

module Chronicle
  RSpec.describe ApiLogs::Metrics do
    around do |example|
      travel_to(Time.zone.local(2026, 6, 15, 12, 0, 0)) do
        example.run
      end
    end

    describe '.kpi_cards' do
      let!(:user1) { User.create!(email: 'user1@example.com', name: 'User 1') }
      let!(:user2) { User.create!(email: 'user2@example.com', name: 'User 2') }

      let(:base_time) { Time.current.beginning_of_hour }

      before do
        # Create successful API logs
        create_api_log(user1, 'device1', 200, 100, base_time)
        create_api_log(user1, 'device1', 200, 150, base_time + 5.minutes)
        create_api_log(user2, 'device2', 200, 200, base_time + 10.minutes)
        create_api_log(user1, 'device1', 200, 250, base_time + 15.minutes)

        # Create error API logs
        create_api_log(user2, 'device2', 404, 50, base_time + 20.minutes)
        create_api_log(user1, 'device3', 500, 300, base_time + 25.minutes)

        # Additional logs for P95 calculation
        (1..94).each do |i|
          create_api_log(user1, 'device1', 200, i * 10, base_time + (30 + i).minutes)
        end
      end

      context 'without filters' do
        it 'returns correct KPI metrics' do
          result = described_class.kpi_cards(filters: {})

          expect(result[:total_api_calls]).to eq(100)
          expect(result[:unique_users]).to eq(2)
          expect(result[:unique_devices]).to eq(3)
          expect(result[:average_response_time]).to be_present
          expect(result[:p50_response_time]).to be_present
          expect(result[:p95_response_time]).to be_present
          expect(result[:p99_response_time]).to be_present
          expect(result[:error_rate_percentage]).to eq(2.0) # 2 errors out of 100
          expect(result[:requests_per_hour]).to be > 0 # Defaults to last 6 months
        end
      end

      context 'with date range filters' do
        it 'filters by start_date and end_date' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: (base_time + 15.minutes).to_date.to_s,
          }

          result = described_class.kpi_cards(filters: filters)

          # Should only count first 4 logs within time range
          expect(result[:total_api_calls]).to eq(100)
          expect(result[:unique_users]).to eq(2)
          expect(result[:requests_per_hour]).to be > 0 # Should calculate based on filter dates
        end
      end

      context 'with device_os filter' do
        before do
          ApiLog.limit(10).update_all(device_os: 'ios')
        end

        it 'filters by device OS' do
          result = described_class.kpi_cards(filters: { device_os: 'ios' })

          expect(result[:total_api_calls]).to eq(10)
        end
      end

      context 'with no data' do
        before { ApiLog.delete_all }

        it 'returns zero values' do
          result = described_class.kpi_cards(filters: {})

          expect(result[:total_api_calls]).to eq(0)
          expect(result[:unique_users]).to eq(0)
          expect(result[:unique_devices]).to eq(0)
          expect(result[:average_response_time]).to eq(0.0)
          expect(result[:p50_response_time]).to eq(0.0)
          expect(result[:p95_response_time]).to eq(0.0)
          expect(result[:p99_response_time]).to eq(0.0)
          expect(result[:error_rate_percentage]).to eq(0.0)
          expect(result[:requests_per_hour]).to eq(0.0)
        end
      end

      context 'P50, P95, P99 calculation' do
        before do
          ApiLog.delete_all

          # Create 100 logs with known response times: 10, 20, ..., 1000
          (1..100).each do |i|
            create_api_log(user1, 'device1', 200, i * 10, base_time + i.minutes)
          end
        end

        it 'calculates P50 correctly' do
          result = described_class.kpi_cards(filters: {})
          # P50 (median) of [10, 20, ..., 1000] = 505.0
          expect(result[:p50_response_time]).to eq(505.0)
        end

        it 'calculates P95 correctly' do
          result = described_class.kpi_cards(filters: {})
          # P95 of [10, 20, ..., 1000] = 950.5
          expect(result[:p95_response_time]).to eq(950.5)
        end

        it 'calculates P99 correctly' do
          result = described_class.kpi_cards(filters: {})
          # P99 of [10, 20, ..., 1000] = 990.1
          expect(result[:p99_response_time]).to eq(990.1)
        end
      end

      context 'error rate calculation' do
        before do
          ApiLog.delete_all

          # 70 successful requests
          70.times { create_api_log(user1, 'device1', 200, 100, base_time) }

          # 20 4xx errors
          20.times { create_api_log(user1, 'device1', 404, 100, base_time) }

          # 10 5xx errors
          10.times { create_api_log(user1, 'device1', 500, 100, base_time) }
        end

        it 'calculates error rate correctly' do
          result = described_class.kpi_cards(filters: {})

          expect(result[:total_api_calls]).to eq(100)
          expect(result[:error_rate_percentage]).to eq(30.0) # 30% error rate
        end
      end

      context 'requests per hour calculation' do
        before do
          ApiLog.delete_all

          # 10 requests over 1 hour
          10.times do |i|
            create_api_log(user1, 'device1', 200, 100, base_time + (i * 6).minutes)
          end
        end

        it 'calculates requests per hour correctly with date filters' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
          }

          result = described_class.kpi_cards(filters: filters)

          expect(result[:total_api_calls]).to eq(10)
          # 10 requests over 1 day (24 hours) = 0.42 requests/hour
          expect(result[:requests_per_hour]).to be_within(0.1).of(0.42)
        end

        it 'returns 0.0 when no date filters provided' do
          result = described_class.kpi_cards(filters: {})

          expect(result[:total_api_calls]).to eq(10)
          expect(result[:requests_per_hour]).to eq(0.0)
        end
      end
    end

    describe '.distribution_metrics' do
      let!(:user1) { User.create!(email: 'user1@example.com', name: 'User 1') }
      let(:base_time) { Time.current.beginning_of_hour }

      before do
        ApiLog.delete_all

        # Create API logs with different status codes
        create_api_log(user1, 'device1', 200, 100, base_time)
        create_api_log(user1, 'device1', 200, 150, base_time + 1.hour)
        create_api_log(user1, 'device1', 200, 200, base_time + 2.hours)
        create_api_log(user1, 'device1', 201, 120, base_time + 3.hours)
        create_api_log(user1, 'device1', 404, 50, base_time + 4.hours)
        create_api_log(user1, 'device1', 500, 300, base_time + 5.hours)
        create_api_log(user1, 'device1', 500, 350, base_time + 6.hours)
      end

      context 'status_code_distribution' do
        it 'returns status codes sorted by frequency' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
          }

          result = described_class.distribution_metrics(filters: filters)

          data = result[:status_code_distribution]
          expect(data).to include(:status_codes, :total_count)
          expect(data[:total_count]).to eq(7)
          expect(data[:status_codes].pluck(:status_code)).to match_array([200, 201, 404, 500])
        end

        it 'for a 6 month range' do
          create_api_log(user1, 'device1', 200, 100, base_time - 5.months)
          create_api_log(user1, 'device1', 200, 100, base_time - 4.months)
          create_api_log(user1, 'device1', 200, 100, base_time - 3.months)

          filters = {
            start_date: (base_time - 6.months).to_date.to_s,
            end_date: base_time.to_date.to_s,
          }
          result = described_class.distribution_metrics(filters: filters)

          data = result[:status_code_distribution]
          expect(data[:total_count]).to eq(10)
        end
      end

      context 'traffic_over_time' do
        it 'returns traffic data with proper labels and counts' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
          }

          result = described_class.distribution_metrics(filters: filters)
          data = result[:traffic_over_time]
          data.all? { |d| expect(d).to include(:label, :count, :timestamp) }
          expect(data.sum { |d| d[:count] }).to eq(7)
          expect(data.size).to eq(24)
        end

        it 'returns data for 6 month range' do
          create_api_log(user1, 'device1', 200, 100, base_time - 5.months)
          create_api_log(user1, 'device1', 200, 100, base_time - 4.months)
          create_api_log(user1, 'device1', 200, 100, base_time - 3.months)

          filters = {
            start_date: (base_time - 6.months).to_date.to_s,
            end_date: base_time.to_date.to_s,
          }
          result = described_class.distribution_metrics(filters: filters)

          data = result[:traffic_over_time]
          expect(data.size).to eq(7)
          expect(data.sum { |d| d[:count] }).to eq(10)
        end

        it 'returns data for 48 hour range with 1-day intervals' do
          # Use a time range far from the before block data
          day1 = (base_time - 10.days).beginning_of_day

          create_api_log(user1, 'device1', 200, 100, day1 + 1.hour)
          create_api_log(user1, 'device1', 200, 100, day1 + 5.hours)
          create_api_log(user1, 'device1', 200, 100, day1 + 1.day + 3.hours)

          filters = {
            start_date: day1.to_date.to_s,
            end_date: (day1 + 1.day).to_date.to_s,
          }
          result = described_class.distribution_metrics(filters: filters)

          data = result[:traffic_over_time]
          expect(data.size).to eq(2) # 2 days with 1-day intervals
          expect(data.sum { |d| d[:count] }).to eq(3)
        end

        it 'returns data for 28 day range with 1-day intervals' do
          # Use a time period different from the before block data
          start_day = (base_time - 40.days).beginning_of_day

          # Create logs across 28 days
          14.times do |i|
            create_api_log(user1, 'device1', 200, 100, start_day + (i * 2).days)
          end

          filters = {
            start_date: start_day.to_date.to_s,
            end_date: (start_day + 27.days).to_date.to_s,
          }
          result = described_class.distribution_metrics(filters: filters)

          data = result[:traffic_over_time]
          expect(data.size).to eq(28) # 28 days / 1 day intervals = 28
          expect(data.sum { |d| d[:count] }).to eq(14)
        end
      end

      context 'response_time_trend' do
        it 'returns response time data with average and p95' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
          }

          result = described_class.distribution_metrics(filters: filters)

          data = result[:response_time_trend]
          expect(data).to be_an(Array)
          expect(data.first).to include(:label, :timestamp, :average_response_time, :p95_response_time)
        end

        it 'returns hourly data for 24 hour range' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
          }

          result = described_class.distribution_metrics(filters: filters)

          data = result[:response_time_trend]
          expect(data.size).to eq(24) # 24 hours with 1-hour intervals

          # Check that each data point has the required fields
          data.each do |point|
            expect(point[:average_response_time]).to be_a(Numeric)
            expect(point[:p95_response_time]).to be_a(Numeric)
            expect(point[:label]).to be_present
            expect(point[:timestamp]).to be_a(Integer)
          end
        end

        it 'returns daily data for 30 day range' do
          start_day = (base_time - 40.days).beginning_of_day

          # Create logs across 30 days with varying response times
          30.times do |i|
            create_api_log(user1, 'device1', 200, 100 + (i * 10), start_day + i.days)
          end

          filters = {
            start_date: start_day.to_date.to_s,
            end_date: (start_day + 29.days).to_date.to_s,
          }

          result = described_class.distribution_metrics(filters: filters)

          data = result[:response_time_trend]
          expect(data.size).to eq(30)

          # Verify we have actual response time data
          non_zero_points = data.select { |d| d[:average_response_time] > 0 }
          expect(non_zero_points.size).to eq(30)
        end

        it 'returns monthly data for 6 month range' do
          start_time = (base_time - 6.months).beginning_of_month

          # Create logs across 6 months
          6.times do |i|
            create_api_log(user1, 'device1', 200, 150 + (i * 20), start_time + i.months + 10.days)
          end

          filters = {
            start_date: start_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
          }

          result = described_class.distribution_metrics(filters: filters)

          data = result[:response_time_trend]
          expect(data.size).to eq(7)

          non_zero_points = data.select { |d| d[:average_response_time] > 0 }
          expect(non_zero_points.size).to eq(6)
        end
      end

      context 'time interval calculation' do
        context 'for 24 hours or less' do
          it 'uses 1 hour intervals' do
            filters = {
              start_date: base_time.to_date.to_s,
              end_date: base_time.to_date.to_s,
            }

            result = described_class.distribution_metrics(filters: filters)

            # For a single day, should have 24 hourly buckets
            expect(result[:traffic_over_time].size).to eq(24)
          end
        end

        context 'for 7 days' do
          it 'uses 1 day intervals' do
            start_date = base_time - 6.days

            filters = {
              start_date: start_date.to_date.to_s,
              end_date: base_time.to_date.to_s,
            }

            result = described_class.distribution_metrics(filters: filters)

            # For 7 days, should have around 7 daily buckets
            expect(result[:traffic_over_time].size).to eq(7)
          end
        end

        context 'for 30 days' do
          it 'uses 1 day intervals' do
            start_date = base_time - 29.days

            filters = {
              start_date: start_date.to_date.to_s,
              end_date: base_time.to_date.to_s,
            }

            result = described_class.distribution_metrics(filters: filters)

            # For 30 days with 1-day intervals, should have 30 buckets
            expect(result[:traffic_over_time].size).to eq(30)
          end
        end

        context 'for more than 30 days' do
          it 'uses monthly intervals' do
            start_date = base_time - 3.months

            filters = {
              start_date: start_date.to_date.to_s,
              end_date: base_time.to_date.to_s,
            }

            result = described_class.distribution_metrics(filters: filters)

            # For 3 months, should have around 3-4 monthly buckets
            expect(result[:traffic_over_time].size).to eq(4)
          end
        end
      end

      context 'with other filters' do
        before do
          ApiLog.update_all(device_os: 'android')
          ApiLog.limit(3).update_all(device_os: 'ios')
        end

        it 'applies device_os filter correctly' do
          filters = {
            start_date: base_time.to_date.to_s,
            end_date: base_time.to_date.to_s,
            device_os: 'ios',
          }

          result = described_class.distribution_metrics(filters: filters)

          total_count = result[:traffic_over_time].sum { |d| d[:count] }
          expect(total_count).to eq(3)
        end
      end
    end

    private

    def create_api_log(user, device_id, status_code, response_time, timestamp)
      ApiLog.create!(
        user_id: user.id,
        device_id: device_id,
        http_status_code: status_code,
        response_time_ms: response_time,
        timestamp: timestamp,
        api_endpoint: '/api/test',
        http_method: 'GET',
        request_id: SecureRandom.uuid
      )
    end
  end
end
