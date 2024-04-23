require 'rack/test'
require 'rspec'
require 'database_cleaner'
require_relative '../app/application'
require 'webmock'
require 'vcr'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.order = 'random'

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.default_cassette_options = { :record => :once }
end

def app
  Application
end
