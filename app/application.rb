require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'

class Application < Sinatra::Base
  configure do
    enable :sessions
  end

  use OmniAuth::Builder do
    provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'], scope: 'email'
  end

  get '/' do
    omniauth_auth = session[:omniauth_auth] ? session[:omniauth_auth] : nil

    if omniauth_auth
      return 'pagina initial'
    end

    redirect '/login'
  end

  get '/login' do   
    erb :login, locals: { 
      google_key: ENV['GOOGLE_KEY'],
      csrf_token: request.env['rack.session']['csrf']
    }
  end

  get '/auth/:provider/callback' do
    content_type 'text/plain'
    begin
      session[:omniauth_auth] = request.env['omniauth.auth'].to_hash
      redirect '/'
      
    rescue StandardError
      'No Data no callback'
    end
  end
end
