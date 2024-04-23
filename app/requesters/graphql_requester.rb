module GraphqlRequester
  attr_reader :params

  def initialize(params)
    @params = params
  end

  private

  def graphql_request(query)
    uri = URI(ENV['GRAPHQL_URL'])
    headers = { 'Content-Type' => 'application/json'}
    body = { query: query }
    response = Net::HTTP.post(uri, body.to_json, headers)
    JSON.parse(response.body)
  rescue StandardError
    Rails.logger.tagged("Graphql Request") do |logger|
      logger.error e.message
      logger.error query
      logger.error e.backtrace.join("\n")
    end

    { errors: [{ message: 'Failed to open TCP connection' }]}
  end
end
