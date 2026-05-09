require 'rails_helper'
module Chronicle
  RSpec.describe AuthController, type: :request do
    let!(:admin_user) { create(:admin_user, email: 'bruno@example.com', password: 'password123') }
    let(:url) { '/chronicle/auth/login' }

    describe 'GET /chronicle/auth/login' do
      context 'with valid API token' do
        it 'returns 400 when email is missing' do
          get url, headers: headers
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns 400 when password is missing' do
          get url, params: { email: admin_user.email }, headers: headers
          expect(response).to have_http_status(:bad_request)
        end

        it 'returns 404 when email is not found' do
          get url, params: { email: 'nobody@example.com', password: 'password123' }, headers: headers
          expect(response).to have_http_status(:not_found)
        end

        it 'returns 401 when password is wrong' do
          get url, params: { email: admin_user.email, password: 'wrong' }, headers: headers
          expect(response).to have_http_status(:unauthorized)
        end

        it 'returns 200 with admin user details on successful login' do
          get url, params: { email: admin_user.email, password: 'password123' }, headers: headers
          expect(response).to have_http_status(:ok)

          body = json(response)['admin_user']
          expect(body['id']).to eq(admin_user.id)
          expect(body['email']).to eq(admin_user.email)
          expect(body['auth_token']).to eq(admin_user.auth_token)
          expect(body.key?('password_digest')).to be false
        end
      end
    end
  end
end
