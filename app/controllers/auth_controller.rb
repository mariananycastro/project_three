require_relative '../helpers/session_helper'
require_relative '../../db/database'

class AuthController < Sinatra::Base
  include SessionHelper

  get '/login' do
    erb :'../views/login', layout: :application,
    locals: {
      google_key: ENV['GOOGLE_KEY'],
      csrf_token: request.env['rack.session']['csrf']
    }
  end

  post '/logout' do
    Session.expire_all(omniauth_auth_email)
    redirect '/login'
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'

    session[:omniauth_auth] = request.env['omniauth.auth'].to_hash
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