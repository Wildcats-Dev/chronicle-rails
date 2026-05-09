require 'rails_helper'

module Chronicle
  RSpec.describe ErrorGroupsController, type: :request do
    let(:admin_user) { create(:admin_user, auth_token: 'test_auth_token') }
    let(:headers)       { { 'X-API-TOKEN' => ENV['API_TOKEN'] || 'test_token' } }
    let(:admin_headers) { headers.merge('X-Admin-Auth-Token' => admin_user.auth_token) }
    let(:admin_url)     { '/chronicle/admin/error_groups' }

    describe 'GET /chronicle/admin/error_groups' do
      let!(:group1) do
        create(:error_group, :from_controller, :open,
               source_name: 'users#show',     error_message: 'Database connection failed',
               backend_version: '1.0.0',      last_seen_at: 2.days.ago)
      end
      let!(:group2) do
        create(:error_group, :from_job, :resolved,
               source_name: 'mailer_job',     error_message: 'Null pointer exception',
               backend_version: '2.0.0',      last_seen_at: 1.day.ago)
      end
      let!(:group3) do
        create(:error_group, :from_controller, :ignored,
               source_name: 'api_controller', error_message: 'Authentication failed',
               last_seen_at: 1.day.from_now)
      end

      context 'with admin auth' do
        it 'returns all error groups' do
          get admin_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data'].length).to eq(3)
        end

        it 'returns empty array when no groups exist' do
          ErrorGroup.delete_all
          get admin_url, headers: admin_headers
          expect(response).to have_http_status(:ok)
          expect(json(response)['data']).to eq([])
        end

        context 'with exact filters' do
          it 'filters by project' do
            get admin_url, params: { filters: { project: 'chronicle' } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(3)
            expect(json(response)['data'].all? { |g| g['project'] == 'chronicle' }).to be true
          end

          it 'filters by source_type' do
            get admin_url, params: { filters: { source_type: 'controller' } }, headers: admin_headers
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |g| g['source_type'] == 'controller' }).to be true
          end

          it 'filters by status' do
            get admin_url, params: { filters: { status: 'open' } }, headers: admin_headers
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['status']).to eq('open')
          end

          it 'filters by fingerprint' do
            get admin_url, params: { filters: { fingerprint: group1.fingerprint } }, headers: admin_headers
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['error_fingerprint']).to eq(group1.fingerprint)
          end

          it 'filters by backend_version' do
            get admin_url, params: { filters: { backend_version: '2.0.0' } }, headers: admin_headers
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['backend_version']).to eq('2.0.0')
          end
        end

        context 'with like filters' do
          it 'filters by source_name partial match' do
            get admin_url, params: { filters: { source_name: 'users' } }, headers: admin_headers
            expect(json(response)['data'].length).to eq(1)
            expect(json(response)['data'][0]['source_name']).to include('users')
          end

          it 'filters by error_message partial match' do
            get admin_url, params: { filters: { error_message: 'failed' } }, headers: admin_headers
            expect(json(response)['data'].length).to eq(2)
            expect(json(response)['data'].all? { |g| g['error_message'].downcase.include?('failed') }).to be true
          end
        end

        context 'with date range filters on last_seen_at' do
          it 'filters from start_date' do
            start_date = 3.days.ago.strftime('%Y-%m-%d')
            get admin_url, params: { filters: { start_date: start_date } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(3)
          end

          it 'filters up to end_date' do
            # group1 (2.days.ago) and group2 (1.day.ago) fall within yesterday;
            # group3 (1.day.from_now) does not.
            end_date = 1.day.ago.strftime('%Y-%m-%d')
            get admin_url, params: { filters: { end_date: end_date } }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['data'].length).to eq(2)
          end
        end

        context 'with pagination' do
          before { create_list(:error_group, 5) }

          it 'returns paginated results ordered by id descending' do
            get admin_url, params: { limit: 3 }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            body = json(response)
            expect(body['data'].length).to eq(3)
            expect(body['pagination']['has_more']).to be true
            expect(body['data'].pluck('id')).to eq(body['data'].pluck('id').sort.reverse)
          end

          it 'returns the next page using a cursor' do
            get admin_url, params: { limit: 5 }, headers: admin_headers
            last_id = json(response)['pagination']['last_id']

            get admin_url, params: { limit: 5, last_id: last_id }, headers: admin_headers
            expect(response).to have_http_status(:ok)
            expect(json(response)['pagination']['has_more']).to be false
            expect(json(response)['pagination']['batch_count']).to eq(3)
          end
        end
      end

      context 'without admin auth' do
        it 'returns forbidden' do
          get admin_url, headers: headers
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'GET /chronicle/admin/error_groups/:id' do
      let!(:group)    { create(:error_group, :from_controller, :open) }
      let(:show_url)  { "/chronicle/admin/error_groups/#{group.id}" }

      it 'returns the error group with all fields' do
        get show_url, headers: admin_headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['id']).to             eq(group.id)
        expect(body['source_type']).to    eq('controller')
        expect(body['status']).to         eq('open')
        expect(body['error_fingerprint']).to eq(group.fingerprint)
        expect(body['occurrence_count']).to  eq(1)
        expect(body['first_seen_at']).to  be_present
        expect(body['last_seen_at']).to   be_present
      end

      it 'returns not found for a non-existent group' do
        get '/chronicle/admin/error_groups/99999', headers: admin_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'PUT /chronicle/admin/error_groups/:id' do
      let!(:group)      { create(:error_group, :open) }
      let(:update_url)  { "/chronicle/admin/error_groups/#{group.id}" }

      it 'updates the status' do
        put update_url, params: { status: 'resolved' }, headers: admin_headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['status']).to eq('resolved')
        expect(group.reload.status).to eq('resolved')
      end

      it 'updates the jira_link' do
        put update_url, params: { jira_link: 'https://jira.example.com/ISSUE-123' }, headers: admin_headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['jira_link']).to eq('https://jira.example.com/ISSUE-123')
        expect(group.reload.jira_link).to eq('https://jira.example.com/ISSUE-123')
      end

      it 'updates status and jira_link together' do
        put update_url, params: { status: 'ignored', jira_link: 'https://jira.example.com/ISSUE-456' },
                        headers: admin_headers
        expect(response).to have_http_status(:ok)
        group.reload
        expect(group.status).to    eq('ignored')
        expect(group.jira_link).to eq('https://jira.example.com/ISSUE-456')
      end

      it 'returns bad request for an invalid status' do
        put update_url, params: { status: 'not_a_valid_status' }, headers: admin_headers
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include('Invalid status')
      end

      it 'returns not found for a non-existent group' do
        put '/chronicle/admin/error_groups/99999', params: { status: 'resolved' }, headers: admin_headers
        expect(response).to have_http_status(:not_found)
      end

      context 'without admin auth' do
        it 'returns forbidden' do
          put update_url, params: { status: 'resolved' }, headers: headers
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
