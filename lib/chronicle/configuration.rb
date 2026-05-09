module Chronicle
  class Configuration
    attr_accessor :user_class,
                  :admin_user_class,
                  :api_token,
                  :project_name,
                  :backend_version,
                  :api_log_buffer,
                  :api_log_flush_interval,
                  :api_log_flush_size,
                  :api_log_buffer_dir,
                  :skip_paths,
                  :skip_api_log_proc,
                  :disable_api_logging,
                  :disable_error_logging

    def initialize
      @user_class             = nil
      @admin_user_class       = 'Chronicle::AdminUser'
      @api_token              = nil
      @project_name           = nil
      @backend_version        = -> {}
      @api_log_buffer         = :file
      @api_log_flush_interval = 30
      @api_log_flush_size     = 500
      @api_log_buffer_dir     = nil
      @skip_paths             = []
      @skip_api_log_proc      = nil
      @disable_api_logging    = false
      @disable_error_logging  = false
    end

    def user_model
      return nil if user_class.nil?
      user_class.is_a?(String) ? user_class.constantize : user_class
    end

    def admin_user_model
      admin_user_class.is_a?(String) ? admin_user_class.constantize : admin_user_class
    end

    def resolved_backend_version
      backend_version.respond_to?(:call) ? backend_version.call : backend_version
    end
  end
end
