# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :trips, only: [:index, :show] do
        member do
          post :record_update
        end
        collection do
          get 'stop_arrivals/:stop_id', to: 'trips#stop_arrivals'
        end
      end
    end
  end
end