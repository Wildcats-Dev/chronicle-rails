source 'https://rubygems.org'

# Specify your gem's dependencies in chronicle.gemspec.
gemspec

gem 'pg'
gem 'puma'

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem 'rubocop-rails-omakase', require: false

group :development, :test do
  gem 'database_cleaner-active_record'
  gem 'debug', platforms: [:mri], require: 'debug/prelude'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry'
  gem 'rspec-rails'
end

group :test do
  gem 'simplecov', require: false
end
