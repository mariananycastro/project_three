require 'rack/test'
require 'rspec'
require 'database_cleaner'
require_relative '../app/application'

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

def app
  Application
end
