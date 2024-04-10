require './app/application'
require 'rack/handler/puma'

Rack::Handler::Puma.run(
  Application,
  Port: 4567,
  Host: '0.0.0.0'
)
