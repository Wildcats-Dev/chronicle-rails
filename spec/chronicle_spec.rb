require 'rails_helper'

RSpec.describe Chronicle do
  it 'has a version number' do
    expect(Chronicle::VERSION).not_to be_nil
  end

  it 'exposes the engine' do
    expect(Chronicle::Engine).to be < Rails::Engine
    expect(Chronicle::Engine.isolated?).to be true
  end

  describe '.configure' do
    before { Chronicle.reset_configuration! }
    after  { Chronicle.reset_configuration! }

    it 'yields a Configuration with sensible defaults' do
      expect(Chronicle.config.admin_user_class).to eq('Chronicle::AdminUser')
      expect(Chronicle.config.api_log_buffer).to eq(:file)
      expect(Chronicle.config.api_log_flush_interval).to eq(30)
    end

    it 'allows callers to override settings' do
      Chronicle.configure do |c|
        c.user_class    = 'User'
        c.project_name  = 'registro'
        c.api_log_buffer = :sync
      end

      expect(Chronicle.config.user_class).to eq('User')
      expect(Chronicle.config.project_name).to eq('registro')
      expect(Chronicle.config.api_log_buffer).to eq(:sync)
    end

    it 'resolves a callable backend_version' do
      Chronicle.configure { |c| c.backend_version = -> { '1.2.3' } }
      expect(Chronicle.config.resolved_backend_version).to eq('1.2.3')
    end
  end
end
