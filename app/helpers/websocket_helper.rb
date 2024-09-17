require 'faye/websocket'

class WebsocketHelper
  def self.connect(clients, env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env)

      clients << ws

      ws.on :open do |_event|
        puts 'WebSocket connection opened'
      end

      ws.on :close do |_event|
        clients.delete(ws)
        puts 'WebSocket connection closed'
      end

      ws.rack_response
    else
      nil
    end
  end

  def self.broadcast(clients, message)
    clients.each { |client| client.send(message) }
  end
end
