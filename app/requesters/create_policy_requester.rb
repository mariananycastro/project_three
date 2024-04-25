require_relative 'graphql_requester'

class CreatePolicyRequester
  include GraphqlRequester

  def self.execute(params)
    new(params).execute
  end

  def execute
    response = graphql_request
    JSON.parse(response)&.deep_symbolize_keys
  end

  private

  def query
    <<-GRAPHQL
    mutation {
      createPolicy(
        policy: {
              effectiveFrom: "#{params[:effective_from]}"
              effectiveUntil: "#{params[:effective_until]}"
              insuredPerson: {
                name: "#{params[:name]}",
                document: "#{params[:document]}",
                email: "#{params[:email]}"
              }
              vehicle: {
                brand: "#{params[:vehicle_brand]}"
                vehicleModel: "#{params[:vehicle_model]}"
                year: "#{params[:year]}"
                licensePlate: "#{params[:license_plate]}"
              }
            }
          ) { response }
        }
      GRAPHQL
  end
end
