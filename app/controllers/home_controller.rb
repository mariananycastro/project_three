
require_relative '../requesters/policies_by_email_requester'
require_relative 'base_controller'

class HomeController < BaseController
  get '/' do
    redirect '/login' if !user_signed_in?

    policies = PolicyByEmailRequester.execute(omniauth_auth_email)

    if policies
      return erb :home, layout: :application,
        locals: {
          policies: policies,
          email: omniauth_auth_email
        }
    end

    erb :'generic_error', layout: :application,
      locals: { email: omniauth_auth_email }
  end
end
