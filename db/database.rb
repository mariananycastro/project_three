require 'sinatra'
require 'sinatra/activerecord'

set :database_file, '../database.yml'

require_relative '../app/models/session'
