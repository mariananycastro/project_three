require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Cognito < OmniAuth::Strategies::OAuth2
      option :name, 'cognito-idp'

      option :client_options, {
        site: ENV['COGNITO_USER_POOL_SITE'],
        authorize_url: '/oauth2/authorize',
        token_url: '/oauth2/token',
        redirect_uri: ENV['COGNITO_REDIRECT_URI']
      }

      info do
        { email: raw_info['email'] }
      end

      def raw_info
        @raw_info ||= access_token.get('/oauth2/userInfo').parsed
      end

      def build_access_token
        authorization_code = request.params['code']
        client.auth_code.get_token(authorization_code)
      end
    end
  end
end
