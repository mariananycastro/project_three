require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'
require_relative './helpers/session_helper'
require_relative './controllers/auth_controller'
require_relative './controllers/policies_controller'
require_relative './controllers/home_controller'

class Application < Sinatra::Base
  EXPIRES_SESSION = 1200 # seconds

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

  helpers SessionHelper

  use HomeController
  use AuthController
  use PoliciesController
end
