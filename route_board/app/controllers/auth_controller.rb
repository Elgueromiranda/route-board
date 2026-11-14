class AuthController < ActionController::Base
  protect_from_forgery with: :exception

  def google
    render :google, layout: false
  end
end