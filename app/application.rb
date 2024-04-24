require 'sinatra'
require 'sinatra/flash'
require 'omniauth'
require 'omniauth-google-oauth2'
require_relative '../db/database'
require_relative './requesters/policies_by_email_requester'
require_relative './requesters/create_policy_requester'

class Application < Sinatra::Base
  LOGIN_PATHS = %r{/(login|logout)}
  AUTH_CALLBACK_PATHS = %r{/(auth/[^/]+/(callback|failure))}

  register Sinatra::Flash

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

  before do
    return if request.path =~ LOGIN_PATHS
    return if request.path =~ AUTH_CALLBACK_PATHS
    return if user_signed_in?

        redirect '/login'
  end

  get '/' do
    policies = PolicyByEmailRequester.execute(omniauth_auth_email)

    if policies
      return erb :'../views/home', layout: :application, locals: {
        policies: policies,
        email: omniauth_auth_email
      }
    end

    erb :'../views/generic_error', layout: :application, locals: {
      email: omniauth_auth_email
    }
  end

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

  get '/new_policy' do
    erb :'../views/new_policy', layout: :application,
      locals: {
        email: omniauth_auth_email
      }
  end

  post '/create_policy' do
    response = CreatePolicyRequester.execute(params.merge(email: omniauth_auth_email))

    if response && !response[:errors]
      flash[:success] = 'Policy successfully created!'
    else
      flash[:failed] = 'Policy not created! Try again later'
    end

    redirect '/'
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'

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

  get '/auth/:provider/failure' do
    content_type 'text/plain'
    'Failure -> callback error'
  end

  def user_signed_in?
    if omniauth_auth_email
      current_session = Session.active_session(omniauth_auth_email)
      return true if current_session && current_session.session_id_correct?(session[:session_id])
    end

    false
  end

  def omniauth_auth_email
    session.dig(:omniauth_auth, 'info', 'email')
  end
end
