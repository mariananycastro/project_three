require 'jwt'

module JwtHelper
  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, ENV['JWT_SECRET_WEBSOCKET'], 'HS256')
  end

  def self.decode(token)
    body = JWT.decode(token, ENV['JWT_SECRET_WEBSOCKET'], true, { algorithm: 'HS256' })[0]
    HashWithIndifferentAccess.new(body)
  rescue
    nil
  end
end
