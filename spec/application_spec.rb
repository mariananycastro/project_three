require 'spec_helper'
require 'pry'
require 'bcrypt'

describe 'Application' do
  describe 'route get' do
    context 'cookies' do
      it 'are configurated' do
        get '/'

        session = last_request.env['rack.session']
        session_options = last_request.env['rack.session.options']

        expect(session[:session_id]).not_to be_nil
        expect(session[:csrf]).not_to be_nil

        expect(session_options[:expire_after]).to eq Application::EXPIRATE_AFTER
        expect(session_options[:httponly]).to be true
        expect(session_options[:secret]).to eq ENV['COOKIE_SECRET']
        expect(last_response).to be_redirect
      end
    end

    context 'when user is NOT authenticated' do
      it 'redirects to the login page' do
        get '/'

        expect(last_response).to be_redirect

        follow_redirect!
        expect(last_request.path).to eq('/login')
      end
    end

    context 'after user is authenticated' do
      context 'with google_oauth2' do
        let(:user_email) { 'bolinha@email.com' }
        let(:google_oauth2_response) do
          OmniAuth.config.test_mode = true

          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
            provider: 'google_oauth2',
            uid: '111111111',
            info: { email: user_email }
          })
        end
        let(:authenticated_session_id) { 'authenticated_session_id' }
        let(:callback_request) do
          get '/auth/google_oauth2/callback',
            {},
            {
              'rack.session' => { 'session_id' => authenticated_session_id },
              'omniauth.auth' => google_oauth2_response
            }            
        end

        context 'when user has active session' do
          let(:update_last_session) do
            last_session = Session.last 
            new_session_id = BCrypt::Password.create(current_session_id)
            Session.last.update!(session_id_digest: new_session_id)
          end
  
          context 'with session_id equal from current session_id' do
            let(:current_session_id) { authenticated_session_id }

            it 'returns initial page ' do
              callback_request
              update_last_session
              follow_redirect!

              expect(last_response.body).to eq 'initial page'
            end
          end

          context 'with session_id different from current session_id' do
            let(:current_session_id) { 'another_session_id' }

            it 'redirects to /login' do
              expect_any_instance_of(Session)
                .to receive(:session_id_correct?)
                .and_return(false)

              callback_request
              update_last_session
              follow_redirect!

              expect(last_response).to be_redirect
              
              follow_redirect!
              
              expect(last_request.path).to eq('/login')
            end
          end
        end

        context 'when user does NOT have active session' do
          let(:expires_last_session) do
            last_session = Session.last 
            Session.last.update!(expires_at: 1.day.ago)
          end

          before do
            callback_request
            expires_last_session
            follow_redirect!
          end

          it 'redirects to /login' do
            expect(last_response).to be_redirect
            
            follow_redirect!

            expect(Session.active_session(user_email)).to eq(nil) 
            expect(last_request.path).to eq('/login')
          end
        end
      end
    end
  end

  context 'route /login' do
    it do
      get '/login'

      expect(last_response.body).to include('Login with Google')
    end
  end

  context 'route /auth/:provider/callback' do
    context 'with google_oauth2' do
      context 'when authentication succed' do
        let(:email) { 'bolinha@email.com' }
        let(:google_oauth2_response) do
          OmniAuth.config.test_mode = true

          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
            provider: 'google_oauth2',
            uid: '111111111',
            info: { email: email }
          })
        end
        let(:old_session) do
          Session.create(
            session_id: '123456789',
            email: email,
            expires_at: 1.day.from_now
          )
        end
        let(:callback_session_id) { 'callback_session_id' }
        subject(:callback_request) do
          get '/auth/google_oauth2/callback',
            {},
            {
              'rack.session' => { 'session_id' => callback_session_id },
              'omniauth.auth' => google_oauth2_response
            }
        end

        before { old_session }

        it 'redirect do home' do
          subject
          follow_redirect!

          expect(last_request.path).to eq('/')
        end

        it 'expires all active sessions from email' do
          subject

          expect(old_session.reload.expires_at).to be < Time.now
        end

        it 'creates new session' do
          expect { subject }.to change { Session.count }.by 1
          expect(BCrypt::Password.new(Session.last.session_id_digest)).to eq callback_session_id
        end
      end
    end
  end

  context 'route /auth/:provider/failure' do
    context 'with google_oauth2' do
      it 'redirect to /auth/failure' do
        get '/auth/google_oauth2/failure'

        expect(last_request.path).to eq('/auth/google_oauth2/failure')

        expect(last_response.body).to eq 'Failure -> callback error'
      end
    end
  end
end
