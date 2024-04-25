require 'sinatra'
require 'sinatra/flash'
require 'omniauth'
require 'omniauth-google-oauth2'
require_relative '../db/database'
require_relative './requesters/policies_by_email_requester'
require_relative './requesters/create_policy_requester'
require_relative './helpers/session_helper'
require_relative './controllers/auth_controller'

class Application < Sinatra::Base
  helpers SessionHelper
  use AuthController

  EXPIRES_SESSION = 1200 # seconds
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
      expire_after: EXPIRES_SESSION
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
end
