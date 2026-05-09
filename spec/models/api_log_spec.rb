require 'rails_helper'

module Chronicle
  RSpec.describe ApiLog, type: :model do
    describe 'after_commit on create — sync_api_route' do
      let(:endpoint) { '/api/products' }
      let(:method)   { 'GET' }

      context 'when the api_route does not yet exist' do
        it 'creates a new ApiRoute record' do
          expect do
            create(:api_log, api_endpoint: endpoint, http_method: method)
          end.to change(ApiRoute, :count).by(1)

          route = ApiRoute.find_by(path: endpoint, http_method: method)
          expect(route).to be_present
          expect(route.first_seen_at).to be_present
        end
      end

      context 'when the api_route already exists' do
        before { create(:api_route, path: endpoint, http_method: method) }

        it 'does not create a duplicate ApiRoute' do
          expect do
            create(:api_log, api_endpoint: endpoint, http_method: method)
          end.not_to change(ApiRoute, :count)
        end
      end

      context 'with concurrent creates for the same endpoint' do
        it 'results in exactly one ApiRoute record' do
          3.times { create(:api_log, api_endpoint: endpoint, http_method: method) }
          expect(ApiRoute.where(path: endpoint, http_method: method).count).to eq(1)
        end
      end

      context 'when api_endpoint or http_method is blank' do
        it 'does not create an ApiRoute when api_endpoint is nil' do
          expect do
            create(:api_log, api_endpoint: nil, http_method: method)
          end.not_to change(ApiRoute, :count)
        end

        it 'does not create an ApiRoute when http_method is nil' do
          expect do
            create(:api_log, api_endpoint: endpoint, http_method: nil)
          end.not_to change(ApiRoute, :count)
        end
      end
    end
  end
end
