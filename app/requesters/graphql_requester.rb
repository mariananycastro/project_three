module GraphqlRequester
  class MissingMethodError < StandardError; end
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def graphql_request
    uri = URI(ENV['GRAPHQL_URL'])
    headers = { 'Content-Type' => 'application/json'}
    body = { query: query }
    response = Net::HTTP.post(uri, body.to_json, headers)
    JSON.parse(response.body)
  rescue MissingMethodError => e
    { errors: [{ message: e.message }] }
  rescue StandardError => e
    { errors: [{ message: 'Failed to open TCP connection' }]}
  end

  def query
    raise MissingMethodError, 'Missing query'
  end

  def execute
    raise MissingMethodError, 'Missing execute'
  end
end
