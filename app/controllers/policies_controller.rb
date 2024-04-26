require_relative '../requesters/create_policy_requester'

class PoliciesController < BaseController
  before do
    redirect '/login' unless user_signed_in?
  end

  get '/new_policy' do
    erb :'new_policy', layout: :application,
      locals: {
        email: omniauth_auth_email
      }
  end

  post '/create_policy' do
    response = CreatePolicyRequester.execute(params.merge(email: omniauth_auth_email))

    if response && !response[:errors]
      flash[:success] = 'Policy successfully created!'
    else
      flash[:failed] = 'Policy not created! Try again later'
    end

    redirect '/'
  end
end
