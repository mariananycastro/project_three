require 'sinatra'
require 'sinatra/activerecord'

set :database_file, '../database.yml'

ActiveRecord::Encryption.configure(
  primary_key: ENV['PRIMARY_KEY'],
  deterministic_key: ENV['DETERMINISTIC_KEY'],
  key_derivation_salt: ENV['KEY_DERIVATION_SALT']
)

require_relative '../app/models/session'
