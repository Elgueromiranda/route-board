Rails.application.routes.draw do
  root "api/v1/trips#index"

  get "/auth/google_oauth2/callback", to: "sessions#create"
  get "/auth/failure",                to: "sessions#failure"
  get "/auth/google",                 to: "auth#google"
  delete "/logout",                   to: "sessions#destroy"

  namespace :api do
    namespace :v1 do
      # public board
      get "trips",        to: "trips#index"
      get "trips/estimates", to: "trips#estimates"
      get "trips/stops", to: "trips#stops"
      get "trips/form_options", to: "trips#form_options"
      post "trips", to: "trips#create"
      get "trips/updates", to: "trip_updates#show"

      # dispatcher
      get  "dispatch/me",                    to: "dispatcher#me"
      get  "dispatch/trips/:trip_id",        to: "dispatcher#show"
      post "dispatch/trips/:trip_id/events", to: "dispatcher#record_event"
    end
  end
end