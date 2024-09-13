require_relative 'graphql_requester'

class PolicyByEmailRequester
  include GraphqlRequester

  def self.execute(params)
    new(params).execute
  end

  def execute
    response = graphql_request
    policies = JSON.parse(response).deep_symbolize_keys

    return if policies[:errors]

    policies[:data][:policiesByEmailQuery]
  end

  private

  def query
    <<-GRAPHQL
      query {
        policiesByEmailQuery(email: "#{params}") {
          effectiveFrom
          effectiveUntil
          status
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
          payment {
            status
            link
            price
          }
        }
      }
    GRAPHQL
  end
end
