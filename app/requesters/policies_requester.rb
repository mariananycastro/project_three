require_relative 'graphql_requester'

class PoliciesRequester
  include GraphqlRequester

  def self.execute
    new.execute
  end

  def execute
    response = graphql_request
    policies = JSON.parse(response).deep_symbolize_keys
  
    return policies[:data][:policiesQuery] if policies[:data]
  end

  private

  def query
    <<-GRAPHQL
      query {
        policiesQuery {
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
