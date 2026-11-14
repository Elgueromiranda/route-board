Rails.application.routes.draw do
  root 'api/v1/trips#index'

  get "/auth/google_oauth2/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  get "/auth/google", to: "auth#google"
  delete "/logout", to: "sessions#destroy"

  namespace :api do
    namespace :v1 do

    get  "dispatch/me", to: "dispatcher#me"
    get  "dispatch/trips/:trip_id", to: "dispatcher#show"
    post "dispatch/trips/:trip_id/events", to: "dispatcher#record_event

    get "routes/:route_id/estimate", to: "route_estimates#show"
    end
  end
end