class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    email = auth&.dig("info", "email")

    allowed_email = ENV.fetch("DISPATCHER_ADMIN_EMAIL", "eliasmiranda.la@gmail.com").downcase

    unless email&.downcase == allowed_email
      redirect_to frontend_dispatch_url(auth_error: "unauthorized"), allow_other_host: true
      return
    end

    session[:dispatcher] = {
      uid: auth["uid"],
      email: email,
      name: auth.dig("info", "name"),
      image: auth.dig("info", "image")
    }

    redirect_to frontend_dispatch_url, allow_other_host: true
  end

  def destroy
    session[:dispatcher] = nil
    head :no_content
  end

  def failure
    redirect_to frontend_dispatch_url(auth_error: "failed"), allow_other_host: true
  end

  private

  def frontend_dispatch_url(auth_error: nil)
    frontend_url = URI.parse(ENV.fetch("FRONTEND_URL", "http://localhost:5173/dispatch"))
    frontend_url.path = "/dispatch"
    frontend_url.query = auth_error ? URI.encode_www_form(auth_error: auth_error) : nil
    frontend_url.fragment = nil
    frontend_url.to_s
  end
end
