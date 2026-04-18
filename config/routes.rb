Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :subscriptions, only: [ :create ]

      resources :users, only: [] do
        resource :subscription, only: [ :show ], module: :users
      end

      namespace :webhooks do
        resource :apple, only: [ :create ]
      end
    end
  end
end
