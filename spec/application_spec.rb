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
                  expect(last_response.body).to include('Maria Silva')
                  expect(last_response.body).to include('maria@email.com')
                  expect(last_response.body).to include('123.456.789-00')
                  expect(last_response.body).to include('Volkswagen')
                  expect(last_response.body).to include('Gol 1.6')
                  expect(last_response.body).to include('2022')
                  expect(last_response.body).to include('ABC-5678')
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

      context 'when request succed' do
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
end
