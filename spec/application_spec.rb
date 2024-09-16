require 'spec_helper'
require 'pry'
require 'bcrypt'

describe 'Application' do
  context 'route get' do
    context 'cookies' do
      it 'are configurated' do
        get '/'

        session = last_request.env['rack.session']
        session_options = last_request.env['rack.session.options']

        expect(session[:session_id]).not_to be_nil
        expect(session[:csrf]).not_to be_nil

        expect(session_options[:expire_after]).to eq Application::EXPIRES_SESSION
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

            context 'when returns policies' do
              let(:user_email) { 'maria@email.com' }

              it 'Display policies info' do
                VCR.use_cassette('get_policies_by_email') do
                  callback_request
                  update_last_session
                  follow_redirect!

                  expect(last_response.body).to include('2024-03-19')
                  expect(last_response.body).to include('2025-03-19')
                  expect(last_response.body).to include('draft')
                  expect(last_response.body).to include('Maria Silva')
                  expect(last_response.body).to include('maria@email.com')
                  expect(last_response.body).to include('123.456.789-00')
                  expect(last_response.body).to include('Volkswagen')
                  expect(last_response.body).to include('Gol 1.6')
                  expect(last_response.body).to include('2022')
                  expect(last_response.body).to include('ABC-5678')
                  expect(last_response.body).to include('pending')
                  expect(last_response.body).to include('1000.0')
                end
              end
            end

            context 'when returns NO policies' do
              let(:user_email) { 'no_policies@email.com' }

              it 'returns home page ' do
                VCR.use_cassette('get_policies_no_policies') do
                  callback_request
                  update_last_session
                  follow_redirect!

                  expect(last_response.body).to include("Logged in as: #{user_email}")
                  expect(last_response.body).to include('View policies')
                  expect(last_response.body).to include('Create New Policy')
                  expect(last_response.body).to include('Logout')
                  expect(last_response.body).to include('All policies')
                  expect(last_response.body).not_to include('Login')
                  expect(last_response.body).to include('No policies')
                end
              end
            end

            context 'when something goes wrong' do
              let(:user_email) { 'maria@email.com' }

              it do
                allow(Net::HTTP).to receive(:post).and_raise(StandardError)

                callback_request
                update_last_session
                follow_redirect!

                expect(last_response.body).to include('Ops.. something went wrong')
              end
            end
          end

          context 'with session_id different from current session_id' do
            let(:current_session_id) { 'another_session_id' }
            let(:user_email) { 'maria@email.com' }

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
              expect(last_response.body).to include('Login')
              expect(last_response.body).to include('Login with Google')
              expect(last_response.body).not_to include("Logged in as: #{user_email}")
            end
          end
        end

        context 'when user does NOT have active session' do
          let(:expires_last_session) do
            last_session = Session.last
            Session.last.update!(expires_at: 1.day.ago)
          end
          let(:user_email) { 'maria@email.com' }

          it 'redirects to /login' do
            callback_request
            expires_last_session
            follow_redirect!

            expect(last_response).to be_redirect

            follow_redirect!

            expect(Session.active_session(user_email)).to eq(nil)
            expect(last_request.path).to eq('/login')
          end
        end
      end

      context 'with cognito' do
        let(:user_email) { 'john_silva@example.com' }
        let(:user_password) { 'admin1234' }
        let(:cognito_idp_response) do
          OmniAuth.config.test_mode = true

          OmniAuth.config.mock_auth[:cognito_idp] = OmniAuth::AuthHash.new({
            provider: 'cognito_idp',
            uid: '111111111',
            info: { email: user_email }
          })
        end
        let(:authenticated_session_id) { 'authenticated_session_id' }
        let(:callback_request) do
          get '/auth/cognito_idp/callback',
            { username: user_email, password: user_password },
            {
              'rack.session' => { 'session_id' => authenticated_session_id },
              'omniauth.auth' => cognito_idp_response
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

            context 'when returns policies from many users' do
              it 'Display policies info' do
                VCR.use_cassette('get_all_policies') do
                  callback_request
                  update_last_session
                  follow_redirect!

                  expect(last_response.body).to include('draft')
                  expect(last_response.body).to include('Bolinha Silva')
                  expect(last_response.body).to include('email@email.com.br')
                  expect(last_response.body).to include('111.111.111-11')
                  expect(last_response.body).to include('Bolinha Movel')

                  expect(last_response.body).to include('active')
                  expect(last_response.body).to include('Maria Silva')
                  expect(last_response.body).to include('user_email@email.com')
                  expect(last_response.body).to include('222.222.222-22')
                  expect(last_response.body).to include('Novo modelo')
                end
              end
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
              expect(last_response.body).to include('Login')
              expect(last_response.body).to include('Login with Google')
              expect(last_response.body).not_to include("Logged in as: #{user_email}")
            end
          end
        end

        context 'when user does NOT have active session' do
          let(:expires_last_session) do
            last_session = Session.last
            Session.last.update!(expires_at: 1.day.ago)
          end

          it 'redirects to /login' do
            callback_request
            expires_last_session
            follow_redirect!

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
    it 'show login content' do
      get '/login'

      expect(last_response.body).to include('Login')
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
          callback_request
          follow_redirect!

          expect(last_request.path).to eq('/')
        end

        it 'expires all active sessions from email' do
          callback_request

          expect(old_session.reload.expires_at).to be < Time.now
        end

        it 'creates new session' do
          expect { callback_request }.to change { Session.count }.by 1
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

  context 'route /logout' do
    let(:email) { 'maria@email.com' }

    it 'expires all sessions from email'do
      allow_any_instance_of(SessionHelper).to receive(:omniauth_auth_email).and_return(email)
      allow(Session).to receive(:expire_all)

      post '/logout'

      expect(Session).to have_received(:expire_all).with(email)

      follow_redirect!

      expect(last_request.path).to eq '/login'
    end
  end

  context 'route /new_policy' do
    context 'when user is logged' do
      let(:email) { 'maria@email.com' }

      it 'show create policy form' do
        allow_any_instance_of(SessionHelper).to receive(:omniauth_auth_email).and_return(email)
        allow_any_instance_of(SessionHelper).to receive(:user_signed_in?).and_return(true)

        get '/new_policy'

        expect(last_request.path).to eq('/new_policy')
        expect(last_response.body).to include('Create a new policy')
      end
    end

    context 'when user is NOT logged' do
      it 'redirect do login' do
        get '/new_policy'

        follow_redirect!

        expect(last_request.path).to eq '/login'
      end
    end
  end

  context 'route /create_policy' do
    let(:policy_params) do
      {
        effective_from: '2024-04-23',
        effective_until: '2025-04-24',
        name: 'Maria Silva',
        document: '222.222.222-22',
        vehicle_brand: 'Super top',
        vehicle_model: 'Novo modelo',
        year: '2020',
        license_plate: 'ASD-0988'
      }
    end

    context 'when user is NOT logged' do
      it 'redirect do login' do
        post '/create_policy', policy_params

        follow_redirect!

        expect(last_request.path).to eq '/login'
      end
    end

    context 'when user is logged' do
      let(:google_oauth2_response) do
        OmniAuth.config.test_mode = true

        OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: '111111111',
          info: { email: 'user_email@email.com' }
        })
      end
      let(:callback_request) do
        get '/auth/google_oauth2/callback',
          {},
          { 'omniauth.auth' => google_oauth2_response }
      end

      before do
        allow_any_instance_of(SessionHelper).to receive(:user_signed_in?).and_return(true)
      end

      context 'when request succeed' do
        it 'redirects to home' do
          VCR.use_cassette('create_policy') do
            callback_request

            post '/create_policy', policy_params
          end

          expect(last_response).to be_redirect
          follow_redirect!

          expect(last_request.path).to eq('/')
        end

        it 'shows success flash message' do
          VCR.use_cassette('create_policy') do
            callback_request

            post '/create_policy', policy_params
          end

          follow_redirect!

          flash_message = last_request.env['rack.session.unpacked_cookie_data']['flash']

          expect(flash_message[:success]).to eq('Policy successfully created!')
        end
      end

      context 'when something goes wrong' do
        it 'redirects to home' do
          VCR.use_cassette('create_policy_failed') do
            callback_request

            post '/create_policy', policy_params
          end

          expect(last_response).to be_redirect
          follow_redirect!

          expect(last_request.path).to eq('/')
        end

        it 'shows success flash message' do
          VCR.use_cassette('create_policy_failed') do
            callback_request

            post '/create_policy', policy_params
          end

          follow_redirect!
          flash_message = last_request.env['rack.session.unpacked_cookie_data']['flash']

          expect(flash_message[:failed]).to eq('Policy not created! Try again later')
        end
      end
    end
  end

  context 'route get /connect' do
    context 'when request does not autenticate' do
      context 'when token in invalid' do
        it 'does not create a websocket connection' do
          allow(WebsocketHelper).to receive(:connect)

          get '/connect', { token: 'invalid-token' }

          expect(WebsocketHelper).not_to have_received(:connect)
          expect(last_response.status).to eq(400)
        end
      end

      context 'when does not send token' do
        it 'does not create a websocket connection' do
          allow(WebsocketHelper).to receive(:connect)

          get '/connect'

          expect(WebsocketHelper).not_to have_received(:connect)
          expect(last_response.status).to eq(400)
        end
      end
    end

    context 'when request autenticates' do
      it 'creates a websocket connection' do
        valid_token = { token: 'valid_token' }
        allow(JwtHelper).to receive(:decode).and_return(valid_token)
        allow(WebsocketHelper).to receive(:connect).and_return(true)

        get '/connect', valid_token

        expect(JwtHelper).to have_received(:decode).with(valid_token[:token])
        expect(WebsocketHelper).to have_received(:connect)
        expect(last_response.status).to eq(200)
      end
    end
  end

  context 'route post /broadcast' do
    let(:broadcast_email) { 'broadcast_email@example.com' }
    let(:valid_body) do
      {
        email: broadcast_email,
        id: '12345',
        status: 'active'
      }.to_json
    end

    context 'when request does not autenticate' do
      context 'when does not send token' do
        it 'does not send message' do
          allow(WebsocketHelper).to receive(:broadcast)

          post '/broadcast', valid_body

          expect(WebsocketHelper).not_to have_received(:broadcast)
          expect(last_response.status).to eq(400)
        end
      end

      context 'when does not send valid token' do
        it 'does not send message' do
          allow(WebsocketHelper).to receive(:broadcast)

          env = { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer invalid_token" }
          post '/broadcast', valid_body, env

          expect(WebsocketHelper).not_to have_received(:broadcast)
          expect(last_response.status).to eq(400)
        end
      end
    end

    context 'when request is authenticated' do
      let(:cognito_client) do
        instance_double('Faye::WebSocket', env: {
          'rack.session' => {
            'omniauth_auth' => {
              'provider' => 'cognito_idp',
              'info' => { 'email' => 'user1@example.com' }
            }
          }
        })
      end
      let(:same_email_client) do
        instance_double('Faye::WebSocket', env: {
          'rack.session' => {
            'omniauth_auth' => {
              'provider' => 'google_oauth2',
              'info' => { 'email' => broadcast_email }
            }
          }
        })
      end
      let(:another_email_client) do
        instance_double('Faye::WebSocket', env: {
          'rack.session' => {
            'omniauth_auth' => {
              'provider' => 'google_oauth2',
              'info' => { 'email' => 'another_email@email.com' }
            }
          }
        })
      end
      let(:clients_list) { [cognito_client, same_email_client, another_email_client] }
      let(:valid_token) { { token: 'valid_token' } }

      let(:mock_client) do
        instance_double(Faye::WebSocket::Client, env: {
          'rack.session' => {
            'omniauth_auth' => {
              'provider' => 'cognito-idp',
              'info' => { 'email' => 'test@example.com' }
            }
          }
        })
      end

      context 'when sends a websocket message' do
        it 'broadcast message' do
          allow(WebsocketHelper).to receive(:broadcast)
          allow(JwtHelper).to receive(:decode).and_return(valid_token)

          env = { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer valid_token" }
          post '/broadcast', valid_body, env

          expect(WebsocketHelper).to have_received(:broadcast)
          expect(last_response.status).to eq(200)
        end

        it 'and sends message to all cognito selected clients' do
          allow(WebsocketHelper).to receive(:broadcast)
          allow(JwtHelper).to receive(:decode).and_return(valid_token)
          allow(WebsocketController).to receive(:clients).and_return(clients_list)

          env = { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer valid_token" }
          post '/broadcast', valid_body, env

          selected_clients = [cognito_client, same_email_client]

          expect(last_response.status).to eq(200)
          expect(WebsocketHelper).to have_received(:broadcast).with(selected_clients, valid_body)
        end
      end
    end
  end
end
