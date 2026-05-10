require_relative 'lib/chronicle/version'

Gem::Specification.new do |spec|
  spec.name        = 'chronicle-rails'
  spec.version     = Chronicle::VERSION
  spec.authors     = ['Sathwik Anil']
  spec.email       = ['sathwik139@gmail.com']
  spec.homepage    = 'https://github.com/Wildcats-Dev/chronicle-rails'
  spec.summary     = 'Pluggable Rails engine for API request and error logging.'
  spec.description = 'Chronicle is a mountable Rails engine that captures API request logs, error logs, and exposes' \
                     'admin endpoints for observability. Designed to be embedded into any Rails application as a' \
                     'drop-in observability layer.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2' # rubocop:disable Gemspec/RequiredRubyVersion

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'bcrypt', '~> 3.1'
  spec.add_dependency 'rails', '>= 7.1', '< 9'
end
