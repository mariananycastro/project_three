require 'sinatra'
require_relative '../helpers/websocket_helper'
require 'faye/websocket'

class WebsocketController < BaseController
  COGNIT_PROVIDERS = %w(cognito_idp cognito-idp)

  set :clients, []

  get '/connect' do
    return status(400) unless authenticate_connection

    WebsocketHelper.connect(settings.clients, request.env)
  end

  post '/broadcast' do
    return status(400) unless authenticate_message

    body = request.body.read
    selected_clients = clients(body)
    WebsocketHelper.broadcast(selected_clients, body)
    status 200
  end

  private

  def authenticate_connection
    token = request.params['token']
    JwtHelper.decode(token)
  end

  def authenticate_message
    token = request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
    JwtHelper.decode(token)
  end

  def clients(body)
    all_clients = settings.clients
    current_email = JSON.parse(body)['email']

    all_clients.map do |client|
      client_provider = client.env['rack.session']['omniauth_auth']['provider']
      client_email = client.env['rack.session']['omniauth_auth']['info']['email']

      client if COGNIT_PROVIDERS.include?(client_provider) || client_email == current_email
    end
  end
end
