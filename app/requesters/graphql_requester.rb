require 'jwt'

module GraphqlRequester
  class MissingMethodError < StandardError; end
  EXPIRATE_TOKEN = 600 # in seconds

  attr_reader :params

  def initialize(params)
    @params = params
  end

  def graphql_request
    uri = URI(ENV['GRAPHQL_URL'])

    expiration_time = Time.now.to_i + EXPIRATE_TOKEN
    jwt_token = JWT.encode({ exp: expiration_time }, ENV['JWT_SECRET'], ENV['JWT_ALGORITHM'])

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{jwt_token}"
    }
    body = { query: query }.to_json

    response = Net::HTTP.post(uri, body, headers)
    response.body
  rescue MissingMethodError => e
    JSON.generate({ errors: [{ message: e.message }] })
  rescue StandardError => e
    JSON.generate({ errors: [{ message: 'Failed to open TCP connection' }]})
  end

  def query
    raise MissingMethodError, 'Missing query'
  end

  def execute
    raise MissingMethodError, 'Missing execute'
  end

  private

  def jwt_token
    JWT.encode(payload, ENV['JWT_SECRET'], ENV['JWT_ALGORITHM'])
  end
end
