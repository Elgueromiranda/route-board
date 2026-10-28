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
    get 'stops/:stop_id/arrivals', to: 'trips#stop_arrivals'
    get 'arrivals/stream', to: 'arrivals_stream#index'
    end
  end
end