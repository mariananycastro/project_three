require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'
require_relative '../db/database'

class Application < Sinatra::Base
  EXPIRATE_AFTER = 120 # seconds

  configure do
    enable :sessions

    set :session_options, {
      secure: production?,
      httponly: true,
    }

    use Rack::Session::Cookie,
      key: 'my_app_session',
      secret: ENV['COOKIE_SECRET'],
      expire_after: EXPIRATE_AFTER
  end

  use OmniAuth::Builder do
    provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'], scope: 'email'
  end

  get '/' do
    omniauth_auth_email = session[:omniauth_auth] ? session[:omniauth_auth]['info']['email'] : nil

    if omniauth_auth_email
      current_session = Session.active_session(omniauth_auth_email)
      if current_session && current_session.session_id_correct?(session[:session_id])
        return 'initial page'
      end
    end
    redirect '/login'
  end

  get '/login' do   
    erb :'../views/login', locals: { 
      google_key: ENV['GOOGLE_KEY'],
      csrf_token: request.env['rack.session']['csrf']
    }
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'

    begin
      session[:omniauth_auth] = request.env['omniauth.auth'].to_hash
      user_email = session[:omniauth_auth]['info']['email']

      Session.expire_all(user_email)

      Session.create(
        session_id: session[:session_id],
        email: user_email,
        expires_at: EXPIRATE_AFTER.seconds.from_now
      )
      
      redirect '/'
    end
  end

  get '/auth/:provider/failure' do
    content_type 'text/plain'
    'Failure -> callback error'
  end
end
