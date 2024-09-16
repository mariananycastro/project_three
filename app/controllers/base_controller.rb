require 'sinatra'
require 'sinatra/flash'
require_relative '../helpers/session_helper'
require_relative '../helpers/jwt_helper'

class BaseController < Sinatra::Base
  include SessionHelper
  include JwtHelper

  set :views, File.expand_path('../../views', __FILE__)

  register Sinatra::Flash
end
