
require_relative '../requesters/policies_by_email_requester'
require_relative '../requesters/policies_requester'
require_relative 'base_controller'

class HomeController < BaseController
  COGNIT_PROVIDERS = %w(cognito_idp cognito-idp)

  get '/' do
    redirect '/login' unless user_signed_in?

    if COGNIT_PROVIDERS.include?(session['omniauth_auth']['provider'])
      policies = PoliciesRequester.execute
    else
      policies = PolicyByEmailRequester.execute(omniauth_auth_email)
    end

    if policies
      return erb :home, layout: :application,
        locals: {
          policies: policies,
          email: omniauth_auth_email,
          token: token,
          error: false
        }
    end

    erb :'generic_error', layout: :application,
      locals: {
        email: omniauth_auth_email,
        error: true
      }
  end

  private

  def token
    JwtHelper.encode({ email: omniauth_auth_email })
  end
end
