require_relative 'graphql_requester'

class PolicyByEmailRequester
  include GraphqlRequester

  def self.execute(params)
    new(params).execute
  end

  def execute
    policies = graphql_request

    return if policies[:errors]

    policies.deep_symbolize_keys[:data][:policiesByEmailQuery]
  end

  private

  def query
    <<-GRAPHQL
      query {
        policiesByEmailQuery(email: "#{params}") {
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
end
