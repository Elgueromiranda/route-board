Rails.application.routes.draw do
    root 'api/v1/trips#index'


namespace :api do
  namespace :v1 do
    post 'dispatcher/trips', to: 'dispatcher#create_trip'
    post 'dispatcher/trips/:trip_id/stops', to: 'dispatcher#add_stop'
  end
end
end