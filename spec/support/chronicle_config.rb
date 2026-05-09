RSpec.configure do |config|
  # Re-apply test config before each example so that specs which call
  # Chronicle.reset_configuration! (e.g. chronicle_spec.rb) don't bleed into others.
  config.before(:each) do
    Chronicle.configure do |c|
      c.api_token        = 'test_api_token'
      c.project_name     = 'test_project'
      c.insert_middleware = false
      c.user_class = User
    end
  end
end
