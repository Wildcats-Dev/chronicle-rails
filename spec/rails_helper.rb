require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require_relative 'dummy/config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'database_cleaner/active_record'

# factory_bot_rails defaults to the dummy app root for engines; point it at the engine's own factories.
FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
FactoryBot.find_definitions
# Rails.root points to spec/dummy in engine specs; use __dir__ to load from the engine's spec/support.
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

# Run any pending engine migrations automatically rather than aborting.
# maintain_test_schema! only sees the dummy app's db/migrate (empty); the engine's
# migrations are discovered separately, so we migrate the engine path explicitly.
engine_migrations = Chronicle::Engine.root.join('db/migrate').to_s
ActiveRecord::MigrationContext.new([engine_migrations]).migrate

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation, except: %w[schema_migrations ar_internal_metadata])
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end
