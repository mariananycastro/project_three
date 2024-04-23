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
    redirect '/login' unless user_signed_in?

      policies = get_policies_by_email

      return 'Ops.. something went wrong' unless policies

      return erb :'../views/home', layout: :application, locals: {
        policies: policies,
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
    redirect '/login' unless user_signed_in?

    erb :'../views/new_policy', layout: :application,
    locals: {
      email: omniauth_auth_email
    }
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
    session[:omniauth_auth] ? session[:omniauth_auth]['info']['email'] : nil
  end

  def graphql_request(query)
    uri = URI(ENV['GRAPHQL_URL'])
    headers = { 'Content-Type' => 'application/json'}
    body = { query: query }
    response = Net::HTTP.post(uri, body.to_json, headers)

    response ? JSON.parse(response.body) : nil
  end

  def policies_by_email_query
    <<-GRAPHQL
      query {
        policiesByEmailQuery(email: "#{omniauth_auth_email}") {
          effectiveFrom
          effectiveUntil
          insuredPerson {
            name
            email
            document
          }
          vehicle {
            brand
            vehicleModel
            year
            licensePlate
          }
        }
      }
    GRAPHQL
  end

  def get_policies_by_email
    policies = graphql_request(policies_by_email_query)
    policies.deep_symbolize_keys[:data][:policiesByEmailQuery]
  end
end
