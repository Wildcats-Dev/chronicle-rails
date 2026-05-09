Chronicle::Engine.routes.draw do
  # Auth (admin login only — sync endpoints removed, no longer needed as a separate service)
  get 'auth/login', to: 'auth#login'

  # API log updates + metrics (create is handled internally via service/buffer, not HTTP)
  resources :api_logs, only: [] do
    collection do
      put  ':request_id', to: 'api_logs#update', as: :update
      get  :kpi_cards
      get  :distribution_metrics
    end
  end

  # Error log deletion (create is handled internally via Chronicle.log_error)
  resources :error_logs, only: [:destroy]

  # Admin-only reads and management
  scope :admin, as: :admin do
    resources :api_logs,    only: [:index, :show]
    resources :error_logs,  only: [:index, :show]
    resources :error_groups, only: [:index, :show, :update]
    resources :api_routes, only: [:index] do
      collection do
        get :stats
      end
    end
  end
end
