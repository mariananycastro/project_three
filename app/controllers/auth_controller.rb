require 'omniauth'
require 'omniauth-google-oauth2'
require_relative '../../db/database'
require_relative 'base_controller'
require 'omniauth-cognito-idp'

class AuthController < BaseController
  use OmniAuth::Builder do
    provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'], scope: 'email'
    provider :cognito_idp, ENV['COGNITO_CLIENT_ID'], ENV['COGNITO_CLIENT_SECRET'],
      client_options: {
        site: ENV['COGNITO_USER_POOL_SITE']
      },
      name: 'cognito_idp',
      scope: 'email openid'

  end

  get '/login' do
    erb :login, layout: :application,
    locals: {
      csrf_token: request.env['rack.session']['csrf']
    }
  end

  post '/logout' do
    Session.expire_all(omniauth_auth_email)
    redirect '/login'
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'

    omniauth_info = request.env['omniauth.auth'].to_hash.reject {|k| k == 'credentials' || k == 'extra' }

    session[:omniauth_auth] = omniauth_info
    user_email = session[:omniauth_auth]['info']['email']

    Session.expire_all(user_email)

    Session.create(
      session_id: session[:session_id],
      email: user_email,
      expires_at: Application::EXPIRES_SESSION.seconds.from_now
    )

    redirect '/'
  end

  get '/auth/:provider/failure' do
    content_type 'text/plain'
    'Failure -> callback error'
  end
end
